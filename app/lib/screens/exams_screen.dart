import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/exam.dart';
import '../providers/auth_provider.dart';
import '../providers/exams_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/state_views.dart';

class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examsProvider);

    return examsAsync.when(
      loading: () => const _ExamsLoadingPlaceholder(),
      error: (error, _) {
        if (error is ApiException && error.isSessionExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(authProvider.notifier).handleSessionExpired();
          });
        }
        final offline = error is ApiException && error.isConnectivityProblem;
        return MessageView(
          icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
          title: offline ? 'Pas de connexion' : 'Impossible de charger les examens',
          subtitle: offline
              ? 'Vos examens n\'ont pas encore été enregistrés hors ligne.'
              : (error is ApiException ? error.code : 'Vérifiez votre connexion.'),
          tint: AppColors.danger,
          action: FilledButton(
            onPressed: () => ref.invalidate(examsProvider),
            child: const Text('Réessayer'),
          ),
        );
      },
      data: (view) => Column(
        children: [
          if (view.capturedAt case final capturedAt?) OfflineBanner(capturedAt: capturedAt),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(examsProvider.future),
              color: AppColors.purple,
              backgroundColor: AppColors.surfaceRaised,
              child: _ExamsContent(schedule: view.schedule),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamsLoadingPlaceholder extends ConsumerWidget {
  const _ExamsLoadingPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peeked = ref.watch(examsCachePeekProvider);
    return peeked.when(
      data: (cached) => cached == null
          ? const _ExamsSkeleton()
          : Stack(
              children: [
                _ExamsContent(schedule: cached.exams),
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
      loading: () => const _ExamsSkeleton(),
      error: (_, _) => const _ExamsSkeleton(),
    );
  }
}

class _ExamsContent extends StatelessWidget {
  final ExamsSchedule schedule;

  const _ExamsContent({required this.schedule});

  @override
  Widget build(BuildContext context) {
    if (!schedule.hasExams) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const MessageView(
              icon: Icons.event_available_rounded,
              title: 'Aucun examen à venir',
              subtitle: 'Profitez-en — rien n\'est programmé pour l\'instant.',
              tint: AppColors.green,
            ),
          ),
        ),
      );
    }

    final exams = schedule.exams;
    final next = exams.first;
    final rest = exams.skip(1).toList();
    final grouped = _groupByDay(rest);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.md),
          child: Text('Prochain examen', style: Theme.of(context).textTheme.titleMedium),
        ),
        _NextExamCard(exam: next),
        if (grouped.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text('À suivre', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final group in grouped) ...[
            _DayHeader(day: group.day),
            for (final exam in group.exams) ...[
              _ExamRow(exam: exam),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }

  static List<_DayGroup> _groupByDay(List<Exam> exams) {
    final groups = <String, _DayGroup>{};
    for (final exam in exams) {
      final day = exam.day;
      final key = day == null ? 'undated' : '${day.year}-${day.month}-${day.day}';
      groups.putIfAbsent(key, () => _DayGroup(day: day, exams: [])).exams.add(exam);
    }
    return groups.values.toList();
  }
}

class _DayGroup {
  final DateTime? day;
  final List<Exam> exams;
  _DayGroup({required this.day, required this.exams});
}

class _NextExamCard extends StatelessWidget {
  final Exam exam;

  const _NextExamCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    final color = examTypeColor(exam.type);
    final mono = Theme.of(context).extension<AppTypography>()!.monoFamily;
    final countdown = relativeDay(exam.day);

    return AppCard(
      accent: color,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ExamTypeBadge(type: exam.type),
              const Spacer(),
              if (countdown != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    countdown,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            exam.matiere,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.2),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                exam.day == null ? 'Date à confirmer' : longDate(exam.day!),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              if (exam.horaire != null) _Meta(icon: Icons.schedule_rounded, text: exam.horaire!, mono: mono),
              if (exam.salle != null) _Meta(icon: Icons.place_outlined, text: exam.salle!, mono: mono),
              if (exam.dureeMinutes != null) _Meta(icon: Icons.hourglass_bottom_rounded, text: '${exam.dureeMinutes} min', mono: mono),
            ],
          ),
          if (exam.enseignant != null || exam.eliminatoire) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (exam.enseignant != null)
                  Expanded(
                    child: Text(
                      exam.enseignant!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                if (exam.eliminatoire) const _Pill(label: 'Éliminatoire', color: AppColors.danger),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  final Exam exam;

  const _ExamRow({required this.exam});

  @override
  Widget build(BuildContext context) {
    final color = examTypeColor(exam.type);
    final mono = Theme.of(context).extension<AppTypography>()!.monoFamily;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            margin: const EdgeInsets.only(right: AppSpacing.md, top: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exam.matiere,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _ExamTypeBadge(type: exam.type, dense: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (exam.horaire != null) _Meta(icon: Icons.schedule_rounded, text: exam.horaire!, mono: mono, small: true),
                    if (exam.salle != null) _Meta(icon: Icons.place_outlined, text: exam.salle!, mono: mono, small: true),
                    if (exam.dureeMinutes != null) _Meta(icon: Icons.hourglass_bottom_rounded, text: '${exam.dureeMinutes} min', mono: mono, small: true),
                    if (exam.eliminatoire) const _Pill(label: 'Éliminatoire', color: AppColors.danger),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime? day;

  const _DayHeader({required this.day});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm, left: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            day == null ? 'Date à confirmer' : longDate(day!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _ExamTypeBadge extends StatelessWidget {
  final ExamType type;
  final bool dense;

  const _ExamTypeBadge({required this.type, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final color = examTypeColor(type);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? AppSpacing.sm : AppSpacing.md, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        type.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 11 : 12,
            ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final String mono;
  final bool small;

  const _Meta({required this.icon, required this.text, required this.mono, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: small ? 13 : 15, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: (small
                  ? Theme.of(context).textTheme.bodySmall
                  : Theme.of(context).textTheme.bodyMedium)
              ?.copyWith(fontFamily: mono, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _ExamsSkeleton extends StatelessWidget {
  const _ExamsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: const [
        SkeletonBox(height: 20, width: 140),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 150, width: double.infinity),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(height: 72, width: double.infinity),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 72, width: double.infinity),
      ],
    );
  }
}

Color examTypeColor(ExamType type) => switch (type) {
      ExamType.ds => AppColors.info,
      ExamType.examen => AppColors.purple,
      ExamType.controle => AppColors.warning,
      ExamType.tp => AppColors.green,
      ExamType.oral => AppColors.info,
      ExamType.dc => AppColors.warning,
      ExamType.pfe => AppColors.purple,
      _ => AppColors.textSecondary,
    };

const _weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
];

String longDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

String? relativeDay(DateTime? day) {
  if (day == null) return null;
  final today = DateTime.now();
  final d0 = DateTime(today.year, today.month, today.day);
  final diff = DateTime(day.year, day.month, day.day).difference(d0).inDays;
  if (diff < 0) return 'Passé';
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Demain';
  if (diff < 7) return 'Dans $diff jours';
  final weeks = (diff / 7).floor();
  return 'Dans $weeks sem.';
}
