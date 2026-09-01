import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/stage.dart';
import '../providers/auth_provider.dart';
import '../providers/stage_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/state_views.dart';

class StageScreen extends ConsumerWidget {
  const StageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stages')),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const _StageSkeleton(),
          error: (error, _) {
            if (error is ApiException && error.isSessionExpired) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(authProvider.notifier).handleSessionExpired();
              });
            }
            final offline = error is ApiException && error.isConnectivityProblem;
            return MessageView(
              icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
              title: offline ? 'Pas de connexion' : 'Impossible de charger les stages',
              subtitle: offline
                  ? 'Aucun stage n\'a encore été enregistré hors ligne.'
                  : (error is ApiException ? error.code : 'Vérifiez votre connexion.'),
              tint: AppColors.danger,
              action: FilledButton(
                onPressed: () => ref.invalidate(stageProvider),
                child: const Text('Réessayer'),
              ),
            );
          },
          data: (view) => Column(
            children: [
              if (view.capturedAt case final capturedAt?) OfflineBanner(capturedAt: capturedAt),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(stageProvider.future),
                  color: AppColors.purple,
                  backgroundColor: AppColors.surfaceRaised,
                  child: view.stages.isEmpty
                      ? const _EmptyStages()
                      : _StageList(stages: view.stages.stages),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStages extends StatelessWidget {
  const _EmptyStages();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        MessageView(
          icon: Icons.work_outline_rounded,
          title: 'Aucun stage',
          subtitle: 'Vos stages (ouvrier, technicien, ingénieur) apparaîtront ici une fois enregistrés.',
        ),
      ],
    );
  }
}

class _StageList extends StatelessWidget {
  final List<Stage> stages;

  const _StageList({required this.stages});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      itemCount: stages.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, i) => _StageCard(stage: stages[i]),
    );
  }
}

class _StageCard extends StatelessWidget {
  final Stage stage;

  const _StageCard({required this.stage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <_Row>[
      _Row(Icons.date_range_rounded, 'Période', _periode(stage)),
      _Row(Icons.apartment_rounded, 'Lieu', stage.lieu),
      _Row(Icons.badge_outlined, 'Encadrant', stage.responsable),
      _Row(Icons.contact_mail_outlined, 'Coordonnées', stage.coordonnees),
      _Row(Icons.subject_rounded, 'Sujet', stage.sujet),
      _Row(Icons.upload_file_outlined, 'Dépôt', _frDate(stage.dateDepot)),
      _Row(Icons.event_available_outlined, 'Soutenance', _soutenance(stage)),
      _Row(Icons.groups_2_outlined, 'Jury', stage.jury.isEmpty ? null : stage.jury.join('\n')),
    ].where((r) => r.value != null && r.value!.trim().isNotEmpty).toList();

    return AppCard(
      accent: AppColors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: AppColors.purpleGlow,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.work_rounded, color: AppColors.purple, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(stage.type.label, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _StatusBadge(
                label: stage.evaluationLabel,
                color: stage.isValidated
                    ? AppColors.green
                    : (stage.isRejected ? AppColors.danger : AppColors.warning),
                icon: stage.isValidated
                    ? Icons.verified_rounded
                    : (stage.isRejected ? Icons.cancel_rounded : Icons.hourglass_bottom_rounded),
              ),
              _StatusBadge(
                label: stage.validationLabel,
                color: switch (stage.validation) {
                  1 => AppColors.green,
                  2 => AppColors.danger,
                  _ => AppColors.textSecondary,
                },
                icon: Icons.assignment_turned_in_outlined,
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              rows[i],
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({required this.label, required this.color, required this.icon});

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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
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

class _StageSkeleton extends ConsumerWidget {
  const _StageSkeleton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peeked = ref.watch(stageCachePeekProvider);
    return peeked.when(
      data: (cached) => cached == null || cached.stages.isEmpty
          ? const _StageSkeletonBars()
          : Stack(
              children: [
                _StageList(stages: cached.stages.stages),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.purple,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            ),
      loading: () => const _StageSkeletonBars(),
      error: (_, _) => const _StageSkeletonBars(),
    );
  }
}

class _StageSkeletonBars extends StatelessWidget {
  const _StageSkeletonBars();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: const [
        SkeletonBox(height: 240, width: double.infinity),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 240, width: double.infinity),
      ],
    );
  }
}

const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];

String? _frDate(DateTime? d) {
  if (d == null) return null;
  return '${d.day} ${_mois[d.month - 1]} ${d.year}';
}

String? _periode(Stage s) {
  final a = _frDate(s.debut), b = _frDate(s.fin);
  if (a == null && b == null) return null;
  if (a != null && b != null) return 'du $a au $b';
  return a ?? b;
}

String? _soutenance(Stage s) {
  final d = s.soutenance;
  if (d == null) return null;
  final date = _frDate(d);
  final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final salle = (s.salle != null && s.salle!.isNotEmpty) ? ' — ${s.salle}' : '';
  return '$date à $time$salle';
}
