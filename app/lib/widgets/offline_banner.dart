import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  final DateTime capturedAt;

  const OfflineBanner({super.key, required this.capturedAt});

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
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
