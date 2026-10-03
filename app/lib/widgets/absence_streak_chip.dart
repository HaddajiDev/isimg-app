import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/streak.dart';
import '../providers/absences_provider.dart';
import '../theme/app_theme.dart';

/// Compact attendance-streak badge for the Absences app bar: a flame + the
/// current run of school days without an absence. Tapping opens the details
/// (current + record). Sundays never count — the institute schedules none.
class AbsenceStreakChip extends ConsumerWidget {
  const AbsenceStreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absences = ref.watch(absencesProvider).valueOrNull?.absences;
    if (absences == null) return const SizedBox.shrink();

    final spotless = absences.totalAbsences == 0;
    final dates = absences.absentDates;
    // Absences exist but the server gave no dated list — nothing to count.
    if (!spotless && dates.isEmpty) return const SizedBox.shrink();

    final stats = spotless ? null : computeAttendanceStreak(dates);
    final accent = spotless ? AppColors.green : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _showDetails(context, stats),
          child: Tooltip(
            message: spotless
                ? 'Aucune absence cette année'
                : '${stats!.current} jour${stats.current > 1 ? 's' : ''} sans absence',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    spotless
                        ? Icons.verified_rounded
                        : Icons.local_fire_department_rounded,
                    size: 16,
                    color: accent,
                  ),
                  if (!spotless) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${stats!.current}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, StreakStats? stats) {
    final spotless = stats == null;
    final accent = spotless ? AppColors.green : AppColors.warning;
    final theme = Theme.of(context);
    final mono = theme.extension<AppTypography>()!.monoFamily;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.c.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        titlePadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
        contentPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        title: Row(
          children: [
            Icon(
              spotless ? Icons.verified_rounded : Icons.local_fire_department_rounded,
              color: accent,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(spotless ? 'Assiduité parfaite' : 'Série en cours'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (spotless)
              Text(
                'Aucune absence de toute l\'année — continuez !',
                style: theme.textTheme.bodyMedium?.copyWith(color: context.c.textSecondary),
              )
            else ...[
              _StatLine(
                value: '${stats.current}',
                unit: stats.current > 1 ? 'jours' : 'jour',
                label: 'sans absence',
                accent: accent,
                mono: mono,
              ),
              const SizedBox(height: AppSpacing.md),
              _StatLine(
                value: '${stats.best}',
                unit: stats.best > 1 ? 'jours' : 'jour',
                label: 'record de l\'année',
                accent: context.c.textSecondary,
                mono: mono,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Les dimanches ne comptent pas.',
              style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color accent;
  final String mono;

  const _StatLine({
    required this.value,
    required this.unit,
    required this.label,
    required this.accent,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFamily: mono,
            color: accent,
            height: 1,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(unit, style: theme.textTheme.bodyMedium?.copyWith(color: context.c.textSecondary)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
          ),
        ),
      ],
    );
  }
}
