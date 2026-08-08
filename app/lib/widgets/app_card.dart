import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Surface container with an optional accent glow along its top edge.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: accent != null ? AppColors.borderStrong : AppColors.border),
      boxShadow: accent != null
          ? [BoxShadow(color: accent!.withValues(alpha: 0.16), blurRadius: 24, spreadRadius: -6)]
          : null,
    );

    final content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: decoration,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: content,
              ),
            ),
    );
  }
}
