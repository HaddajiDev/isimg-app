import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/notifications.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/state_views.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const _NotifSkeleton(),
          error: (error, _) {
            if (error is ApiException && error.isSessionExpired) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(authProvider.notifier).handleSessionExpired();
              });
            }
            final offline = error is ApiException && error.isConnectivityProblem;
            return MessageView(
              icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
              title: offline ? 'Pas de connexion' : 'Impossible de charger les notifications',
              subtitle: offline
                  ? 'Vérifiez votre connexion et réessayez.'
                  : (error is ApiException ? error.code : 'Vérifiez votre connexion.'),
              tint: AppColors.danger,
              action: FilledButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: const Text('Réessayer'),
              ),
            );
          },
          data: (data) => RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsProvider.future),
            color: AppColors.purple,
            backgroundColor: AppColors.surfaceRaised,
            child: _NotifContent(data: data),
          ),
        ),
      ),
    );
  }
}

class _NotifContent extends StatelessWidget {
  final NotifData data;

  const _NotifContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final counts = data.counts.where((c) => c.count > 0).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        if (counts.isNotEmpty) _SummaryCard(total: data.total, counts: counts),
        if (counts.isNotEmpty) const SizedBox(height: AppSpacing.lg),
        if (data.items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: MessageView(
              icon: Icons.notifications_none_rounded,
              title: 'Aucune notification',
              subtitle: 'Vous êtes à jour. Les nouveautés apparaîtront ici.',
            ),
          )
        else
          for (var i = 0; i < data.items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _NotifCard(item: data.items[i]),
          ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final List<NotifCount> counts;

  const _SummaryCard({required this.total, required this.counts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      accent: AppColors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$total', style: theme.textTheme.headlineMedium?.copyWith(color: AppColors.purple)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  total > 1 ? 'nouveautés depuis votre dernière visite' : 'nouveauté depuis votre dernière visite',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final c in counts)
                _CountChip(kind: c.kind, count: c.count),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final NotifKind kind;
  final int count;

  const _CountChip({required this.kind, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = _kindColor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_kindIcon(kind), size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${kind.label} · $count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final NotifItem item;

  const _NotifCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _kindColor(item.kind);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_kindIcon(item.kind), color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.title.isNotEmpty)
                  Text(item.title, style: theme.textTheme.titleMedium),
                if (item.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _kindColor(NotifKind kind) => switch (kind) {
      NotifKind.news => AppColors.purple,
      NotifKind.absence => AppColors.danger,
      NotifKind.demande => AppColors.info,
      NotifKind.exam => AppColors.warning,
      NotifKind.notes => AppColors.green,
      NotifKind.autre => AppColors.textSecondary,
    };

IconData _kindIcon(NotifKind kind) => switch (kind) {
      NotifKind.news => Icons.campaign_rounded,
      NotifKind.absence => Icons.event_busy_rounded,
      NotifKind.demande => Icons.description_rounded,
      NotifKind.exam => Icons.event_note_rounded,
      NotifKind.notes => Icons.bar_chart_rounded,
      NotifKind.autre => Icons.notifications_rounded,
    };

class _NotifSkeleton extends StatelessWidget {
  const _NotifSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: const [
        SkeletonBox(height: 110, width: double.infinity),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 66, width: double.infinity),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 66, width: double.infinity),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 66, width: double.infinity),
      ],
    );
  }
}
