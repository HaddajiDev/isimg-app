import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_info_provider.dart';
import '../theme/app_theme.dart';

class VersionFooter extends ConsumerWidget {
  const VersionFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(appInfoProvider).valueOrNull;
    if (info == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.c.border)),
      ),
      child: Text(
        'ISIMG Étudiant · v${info.version} (${info.buildNumber})',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.c.textMuted,
              fontSize: 10.5,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}
