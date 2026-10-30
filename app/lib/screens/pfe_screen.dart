import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/pfe.dart';
import '../providers/services_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/info_widgets.dart';
import '../widgets/state_views.dart';

class PfeScreen extends ConsumerWidget {
  const PfeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pfeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projet de fin d\'études')),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => LoadErrorView(
            error: e,
            what: 'le PFE',
            onRetry: () => ref.invalidate(pfeProvider),
          ),
          data: (pfe) => RefreshIndicator(
            onRefresh: () => ref.refresh(pfeProvider.future),
            color: AppColors.purple,
            backgroundColor: context.c.surfaceRaised,
            child: pfe == null
                ? const ScrollableFill(
                    child: MessageView(
                      icon: Icons.school_outlined,
                      title: 'Aucun PFE',
                      subtitle: 'Votre projet de fin d\'études apparaîtra ici une fois affecté.',
                    ),
                  )
                : _PfeView(pfe: pfe),
          ),
        ),
      ),
    );
  }
}

class _PfeView extends StatelessWidget {
  final Pfe pfe;

  const _PfeView({required this.pfe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.extension<AppTypography>()!.monoFamily;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        AppCard(
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
                    child: const Icon(Icons.school_rounded, color: AppColors.purple, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(pfe.sujet ?? 'Sujet non renseigné', style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              if (pfe.note != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      pfe.note!.toStringAsFixed(2),
                      style: theme.textTheme.headlineMedium?.copyWith(fontFamily: mono, color: AppColors.green),
                    ),
                    Text(' / 20', style: theme.textTheme.bodyMedium?.copyWith(color: context.c.textMuted)),
                    if (pfe.mention != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      StatusBadge(label: pfe.mention!, color: AppColors.green, icon: Icons.emoji_events_outlined),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              InfoRows([
                InfoRow(Icons.apartment_rounded, 'Lieu', pfe.lieu),
                InfoRow(Icons.badge_outlined, 'Encadrement', pfe.encadreurs.isEmpty ? null : pfe.encadreurs.join('\n')),
                InfoRow(Icons.build_outlined, 'Outils', pfe.outils),
              ]),
            ],
          ),
        ),
        if (pfe.description != null || pfe.travail != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: InfoRows([
              InfoRow(Icons.notes_rounded, 'Description', pfe.description),
              InfoRow(Icons.checklist_rounded, 'Travail demandé', pfe.travail),
            ]),
          ),
        ],
        if (pfe.hasDefense || pfe.dateDepot != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dépôt et soutenance', style: theme.textTheme.titleMedium),
                InfoRows([
                  InfoRow(Icons.upload_file_outlined, 'Dépôt', frDate(pfe.dateDepot)),
                  InfoRow(Icons.plagiarism_outlined, 'Taux de similarité', pfe.plagiat),
                  InfoRow(Icons.event_available_outlined, 'Soutenance', _soutenance(pfe)),
                  InfoRow(Icons.gavel_rounded, 'Président du jury', pfe.president),
                  InfoRow(Icons.rate_review_outlined, 'Rapporteur', pfe.rapporteur),
                ]),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String? _soutenance(Pfe p) {
    final d = p.soutenance;
    if (d == null) return null;
    final at = frDateTime(d)!;
    final end = p.dureeMinutes == null ? null : d.add(Duration(minutes: p.dureeMinutes!));
    final until = end == null
        ? ''
        : ' – ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    final salle = p.salle == null ? '' : ' · ${p.salle}';
    return '$at$until$salle';
  }
}
