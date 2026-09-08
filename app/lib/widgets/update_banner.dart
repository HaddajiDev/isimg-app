import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/update_provider.dart';
import '../theme/app_theme.dart';

/// A slim strip shown at the top of the app when the backend reports a newer
/// build than the one running. Dismissible for the session.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider).valueOrNull;
    final dismissed = ref.watch(updateBannerDismissedProvider);
    if (update == null || dismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Material(
      color: AppColors.purpleGlow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          children: [
            const Icon(Icons.system_update_rounded, size: 18, color: AppColors.purple),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Nouvelle version disponible (v${update.version}) — pensez à mettre à jour.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.c.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            InkResponse(
              onTap: () =>
                  ref.read(updateBannerDismissedProvider.notifier).state = true,
              radius: 18,
              child: Icon(Icons.close_rounded, size: 18, color: context.c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
