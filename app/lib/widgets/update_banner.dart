import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_updater.dart';
import '../providers/updater_provider.dart';
import '../theme/app_theme.dart';

/// Offers a newer build when the bucket has one. Renders nothing otherwise, so
/// it can sit permanently at the top of the shell.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    if (!update.hasUpdate && update.stage != UpdateStage.failed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final release = update.release;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(
            update.stage == UpdateStage.failed
                ? Icons.error_outline_rounded
                : Icons.system_update_rounded,
            size: 18,
            color: update.stage == UpdateStage.failed
                ? AppColors.danger
                : AppColors.purple,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (update.stage) {
                    UpdateStage.downloading => 'Téléchargement…',
                    UpdateStage.readyToInstall => 'Prêt à installer',
                    UpdateStage.failed => 'Mise à jour échouée',
                    _ => 'Version ${release?.versionName} disponible',
                  },
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (update.stage == UpdateStage.downloading)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: update.progress,
                        minHeight: 4,
                        backgroundColor: AppColors.surfaceRaised,
                      ),
                    ),
                  )
                else if (release?.notes case final notes?
                    when update.stage == UpdateStage.available)
                  Text(
                    notes,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (update.stage == UpdateStage.available ||
              update.stage == UpdateStage.failed) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () => ref.read(updateProvider.notifier).downloadAndInstall(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.purple,
                minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(update.stage == UpdateStage.failed ? 'Réessayer' : 'Installer'),
            ),
            IconButton(
              onPressed: () => ref.read(updateProvider.notifier).dismiss(),
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Ignorer',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
