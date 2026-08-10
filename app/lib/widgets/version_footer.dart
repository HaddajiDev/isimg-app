import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_info_provider.dart';
import '../theme/app_theme.dart';

/// A quiet version line pinned under the tab content, present on every
/// screen since it lives in the shell rather than each individual page.
/// Purely informational, so it renders nothing while unresolved rather than
/// a skeleton or error state — there is nothing worth interrupting anyone
/// for here.
class VersionFooter extends ConsumerWidget {
  const VersionFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(appInfoProvider).valueOrNull;
    if (info == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        'ISIMG Étudiant · v${info.version} (${info.buildNumber})',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 10.5,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}
