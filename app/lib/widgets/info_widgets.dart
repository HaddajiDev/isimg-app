import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'state_views.dart';

/// Icon + caption + value, used in the detail cards of the drawer pages.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const InfoRow(this.icon, this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.c.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted)),
                const SizedBox(height: 2),
                Text(value ?? '', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rows separated by hairlines, skipping the empty ones.
class InfoRows extends StatelessWidget {
  final List<InfoRow> rows;

  const InfoRows(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((r) => r.value != null && r.value!.trim().isNotEmpty).toList();
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          visible[i],
        ],
      ],
    );
  }
}

/// A tinted pill: status, tag, count.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Standard load-failure view: routes an expired session to re-login, offers a
/// retry otherwise.
class LoadErrorView extends ConsumerWidget {
  final Object error;
  final String what;
  final VoidCallback onRetry;

  const LoadErrorView({super.key, required this.error, required this.what, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = error;
    if (e is ApiException && e.isSessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authProvider.notifier).handleSessionExpired();
      });
    }
    final offline = e is ApiException && e.isConnectivityProblem;
    return MessageView(
      icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
      title: offline ? 'Pas de connexion' : 'Impossible de charger $what',
      subtitle: offline ? 'Vérifiez votre connexion puis réessayez.' : (e is ApiException ? e.code : null),
      tint: AppColors.danger,
      action: FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
    );
  }
}

/// Wraps a non-scrolling child so pull-to-refresh still works on it.
class ScrollableFill extends StatelessWidget {
  final Widget child;

  const ScrollableFill({super.key, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      );
}
