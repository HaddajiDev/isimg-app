import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../providers/auth_provider.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/state_views.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleProvider);

    return Column(
      children: [
        const _WeekNavigator(),
        Expanded(
          child: scheduleAsync.when(
            loading: () => const _ScheduleSkeleton(),
            error: (error, _) {
              if (error is ApiException && error.isSessionExpired) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(authProvider.notifier).handleSessionExpired();
                });
              }
              return MessageView(
                icon: Icons.cloud_off_rounded,
                title: 'Impossible de charger l\'emploi',
                subtitle: error is ApiException ? error.code : 'Vérifiez votre connexion.',
                tint: AppColors.danger,
                action: FilledButton(
                  onPressed: () => ref.invalidate(scheduleProvider),
                  child: const Text('Réessayer'),
                ),
              );
            },
            data: (schedule) {
              if (!schedule.hasSessions) {
                return const MessageView(
                  icon: Icons.event_available_rounded,
                  title: 'Aucun cours cette semaine',
                  subtitle: 'Rien de prévu — profitez-en.',
                  tint: AppColors.green,
                );
              }
              // Structured per-session rendering is still pending: every week
              // we could test against was empty (summer break), so the markup
              // for real sessions hasn't been verified yet.
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  AppCard(
                    accent: AppColors.purple,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_rounded, color: AppColors.purple, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Séances programmées',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Cette semaine contient des séances. '
                          'L\'affichage détaillé arrive bientôt.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeekNavigator extends ConsumerWidget {
  const _WeekNavigator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleProvider);
    final label = scheduleAsync.maybeWhen(
      data: (schedule) => schedule.weekLabel,
      orElse: () => null,
    );

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
          _NavArrow(
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
                    label ?? '—',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    'Appuyez pour revenir à aujourd\'hui',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          _NavArrow(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Semaine suivante',
            onPressed: () => goToNextWeek(ref),
          ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _NavArrow({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      // Icon-only control: tooltip doubles as the accessibility label.
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
