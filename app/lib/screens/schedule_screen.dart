import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../models/schedule.dart';
import '../providers/auth_provider.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/schedule_grid.dart';
import '../widgets/state_views.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleProvider);

    return Column(
      children: [
        const _WeekNavigator(),
        if (scheduleAsync.valueOrNull?.capturedAt case final capturedAt?)
          _OfflineBanner(capturedAt: capturedAt),
        Expanded(
          child: scheduleAsync.when(
            loading: () => const _ScheduleLoadingPlaceholder(),
            error: (error, _) {
              if (error is ApiException && error.isSessionExpired) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(authProvider.notifier).handleSessionExpired();
                });
              }
              final offline = error is ApiException && error.isConnectivityProblem;
              return MessageView(
                icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                title: offline
                    ? 'Pas de connexion'
                    : 'Impossible de charger l\'emploi',
                subtitle: offline
                    ? 'Cette semaine n\'a pas encore été enregistrée hors ligne.'
                    : (error is ApiException ? error.code : 'Vérifiez votre connexion.'),
                tint: AppColors.danger,
                action: FilledButton(
                  onPressed: () => ref.invalidate(scheduleProvider),
                  child: const Text('Réessayer'),
                ),
              );
            },
            data: (view) => RefreshIndicator(
              onRefresh: () => ref.refresh(scheduleProvider.future),
              color: AppColors.purple,
              backgroundColor: AppColors.surfaceRaised,
              child: _ScheduleContent(
                schedule: view.schedule,
                weekStart: ref.watch(selectedWeekProvider),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleLoadingPlaceholder extends ConsumerWidget {
  const _ScheduleLoadingPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peeked = ref.watch(scheduleCachePeekProvider);
    final weekStart = ref.watch(selectedWeekProvider);

    return peeked.when(
      data: (cached) => cached == null
          ? const _ScheduleSkeleton()
          : Stack(
              children: [
                _ScheduleContent(schedule: cached.schedule, weekStart: weekStart),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.purple,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            ),
      loading: () => const _ScheduleSkeleton(),
      error: (_, _) => const _ScheduleSkeleton(),
    );
  }
}

class _ScheduleContent extends StatelessWidget {
  final Schedule schedule;
  final DateTime weekStart;

  const _ScheduleContent({required this.schedule, required this.weekStart});

  @override
  Widget build(BuildContext context) {
    if (!schedule.hasSessions) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const MessageView(
              icon: Icons.event_available_rounded,
              title: 'Aucun cours cette semaine',
              subtitle: 'Rien de prévu — profitez-en.',
              tint: AppColors.green,
            ),
          ),
        ),
      );
    }

    if (schedule.sessions.isNotEmpty) {
      return ScheduleGrid(sessions: schedule.sessions, weekStart: weekStart);
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: const MessageView(
            icon: Icons.help_outline_rounded,
            title: 'Emploi illisible',
            subtitle: 'Des séances sont prévues mais n\'ont pas pu être lues. '
                'Consultez le site de l\'ISIMG pour cette semaine.',
            tint: AppColors.warning,
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final DateTime capturedAt;

  const _OfflineBanner({required this.capturedAt});

  String get _age {
    final elapsed = DateTime.now().difference(capturedAt);
    if (elapsed.inMinutes < 1) return 'à l\'instant';
    if (elapsed.inMinutes < 60) return 'il y a ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'il y a ${elapsed.inHours} h';
    return 'il y a ${elapsed.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 15, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Hors ligne — copie enregistrée $_age',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekNavigator extends ConsumerWidget {
  const _WeekNavigator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final label = scheduleAsync.maybeWhen(
      data: (view) => view.schedule.weekLabel,
      orElse: () => null,
    );
    final isCurrentWeek = selectedWeek == mondayOf(DateTime.now());

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Semaine précédente',
            onPressed: () => goToPreviousWeek(ref),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => goToCurrentWeek(ref),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label ?? formatWeek(selectedWeek),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    isCurrentWeek
                        ? 'Semaine en cours'
                        : 'Appuyez pour revenir à aujourd\'hui',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isCurrentWeek ? AppColors.green : AppColors.textMuted,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ),
          _NavButton(
            icon: Icons.calendar_month_rounded,
            tooltip: 'Choisir une semaine',
            onPressed: () => _pickWeek(context, ref, selectedWeek),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Semaine suivante',
            onPressed: () => goToNextWeek(ref),
          ),
        ],
      ),
    );
  }

  Future<void> _pickWeek(BuildContext context, WidgetRef ref, DateTime current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,

      firstDate: DateTime(now.year - 6),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Choisir une semaine',

      fieldHintText: 'jj/mm/aaaa',
    );
    if (picked == null) return;
    goToWeekOf(ref, picked);
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _NavButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,

      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceRaised,
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }
}

class _ScheduleSkeleton extends StatelessWidget {
  const _ScheduleSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (var i = 0; i < 4; i++) ...[
          const SkeletonBox(height: 96),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
