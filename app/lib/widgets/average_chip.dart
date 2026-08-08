import 'package:flutter/material.dart';
import '../core/moyenne_calculator.dart';
import '../theme/app_theme.dart';

/// Renders an average, making clear whether it is published or derived.
///
/// Estimates are prefixed with "~" and drawn with a dashed-looking outline, so
/// a provisional figure is never mistaken for an official result.
class AverageChip extends StatelessWidget {
  final Average average;
  final double fontSize;
  final bool boxed;

  const AverageChip({
    super.key,
    required this.average,
    this.fontSize = 13,
    this.boxed = true,
  });

  static Color colorFor(Average average) {
    if (!average.hasValue) return AppColors.textMuted;
    // A simulation is the student's own hypothesis, so it borrows the accent
    // colour instead of a pass/fail verdict it hasn't earned.
    if (average.isSimulated) return AppColors.purple;
    if (average.source == AverageSource.partial) return AppColors.warning;
    return average.value! >= 10 ? AppColors.green : AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).extension<AppTypography>()!.monoFamily;
    final color = colorFor(average);
    final text = average.hasValue
        ? '${average.isEstimate ? '~' : ''}${average.value!.toStringAsFixed(2)}'
        : '—';

    final label = Text(
      text,
      style: TextStyle(
        fontFamily: mono,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );

    if (!boxed) return label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: average.isEstimate ? 0.06 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: color.withValues(alpha: average.isEstimate ? 0.45 : 0.32),
          width: average.isEstimate ? 1.2 : 1,
        ),
      ),
      child: label,
    );
  }
}

/// Explains the "~" marker once per screen.
class EstimateLegend extends StatelessWidget {
  const EstimateLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).extension<AppTypography>()!.monoFamily;

    return Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted, fontSize: 11.5),
              children: [
                TextSpan(
                  text: '~',
                  style: TextStyle(fontFamily: mono, fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text: ' moyenne calculée à partir des notes publiées — '
                      'non officielle. En orange : calcul partiel, des notes '
                      'manquent encore. En violet : simulation incluant vos '
                      'notes provisoires.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
