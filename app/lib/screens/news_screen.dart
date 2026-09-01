import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/news.dart';
import '../providers/auth_provider.dart';
import '../providers/news_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/state_views.dart';

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(newsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Actualités')),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const _NewsSkeleton(),
          error: (error, _) {
            if (error is ApiException && error.isSessionExpired) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(authProvider.notifier).handleSessionExpired();
              });
            }
            final offline = error is ApiException && error.isConnectivityProblem;
            return MessageView(
              icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
              title: offline ? 'Pas de connexion' : 'Impossible de charger les actualités',
              subtitle: offline
                  ? 'Vérifiez votre connexion et réessayez.'
                  : (error is ApiException ? error.code : 'Vérifiez votre connexion.'),
              tint: AppColors.danger,
              action: FilledButton(
                onPressed: () => ref.invalidate(newsProvider),
                child: const Text('Réessayer'),
              ),
            );
          },
          data: (feed) => RefreshIndicator(
            onRefresh: () => ref.refresh(newsProvider.future),
            color: AppColors.purple,
            backgroundColor: AppColors.surfaceRaised,
            child: feed.isEmpty ? const _EmptyNews() : _NewsList(items: feed.items),
          ),
        ),
      ),
    );
  }
}

class _EmptyNews extends StatelessWidget {
  const _EmptyNews();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        MessageView(
          icon: Icons.campaign_outlined,
          title: 'Aucune actualité',
          subtitle: 'Les annonces de l\'établissement apparaîtront ici.',
        ),
      ],
    );
  }
}

class _NewsList extends StatelessWidget {
  final List<NewsItem> items;

  const _NewsList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => _NewsCard(item: items[i]),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;

  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = item.description ?? item.body;

    return AppCard(
      accent: AppColors.purple,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _NewsDetailScreen(item: item)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: AppColors.purpleGlow,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.campaign_rounded, color: AppColors.purple, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.auteur != null)
                      Text(
                        item.auteur!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    Text(
                      frTimeAgo(item.created),
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(item.titre, style: theme.textTheme.titleMedium),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (item.groupes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [for (final g in item.groupes) _Chip(g)],
            ),
          ],
        ],
      ),
    );
  }
}

class _NewsDetailScreen extends StatelessWidget {
  final NewsItem item;

  const _NewsDetailScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Actualité')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
          children: [
            Text(item.titre, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (item.auteur != null) ...[
                  const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      item.auteur!,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                const Icon(Icons.schedule_rounded, size: 15, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  frDate(item.created),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            if (item.groupes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [for (final g in item.groupes) _Chip(g)],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              item.body.isEmpty ? (item.description ?? '') : item.body,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.info,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _NewsSkeleton extends StatelessWidget {
  const _NewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: const [
        SkeletonBox(height: 150, width: double.infinity),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 150, width: double.infinity),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 150, width: double.infinity),
      ],
    );
  }
}

const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];

String frDate(DateTime? d) {
  if (d == null) return '';
  return '${d.day} ${_mois[d.month - 1]} ${d.year}';
}

String frTimeAgo(DateTime? d) {
  if (d == null) return '';
  final elapsed = DateTime.now().difference(d);
  if (elapsed.inMinutes < 1) return 'à l\'instant';
  if (elapsed.inMinutes < 60) return 'il y a ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'il y a ${elapsed.inHours} h';
  if (elapsed.inDays < 7) return 'il y a ${elapsed.inDays} j';
  return frDate(d);
}
