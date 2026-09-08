import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../providers/update_provider.dart';
import '../theme/app_theme.dart';

/// A slim strip shown at the top of the app when the backend reports a newer
/// build than the one running. Offers a Play Store link and a session dismiss.
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Row(
          children: [
            const Icon(Icons.system_update_rounded, size: 18, color: AppColors.purple),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Nouvelle version disponible (v${update.version}).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.c.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _UpdateButton(onTap: _openStore),
            InkResponse(
              onTap: () =>
                  ref.read(updateBannerDismissedProvider.notifier).state = true,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Icon(Icons.close_rounded, size: 18, color: context.c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(kPlayStoreUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort: if the store can't be opened, the banner just stays.
    }
  }
}

class _UpdateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _UpdateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.purple,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          child: Text(
            'Mettre à jour',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
