import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/grade_tree.dart';
import '../models/grades.dart';
import '../providers/grades_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/info_widgets.dart';
import '../widgets/state_views.dart';

/// The current year's programme: units and modules with their coefficients,
/// credits, régime and evaluation weights — read from the relevé.
class PlanEtudesScreen extends ConsumerWidget {
  const PlanEtudesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentYearGradesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan d\'études')),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => LoadErrorView(
            error: e,
            what: 'le plan d\'études',
            onRetry: () => ref.invalidate(currentYearGradesProvider),
          ),
          data: (grades) => RefreshIndicator(
            onRefresh: () => ref.refresh(currentYearGradesProvider.future),
            color: AppColors.purple,
            backgroundColor: context.c.surfaceRaised,
            child: _Content(grades: grades),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final Grades grades;

  const _Content({required this.grades});

  @override
  Widget build(BuildContext context) {
    final semesters = grades.semesters.where((s) => s.unites.isNotEmpty).toList();
    if (semesters.isEmpty) {
      return const ScrollableFill(
        child: MessageView(
          icon: Icons.menu_book_outlined,
          title: 'Plan d\'études indisponible',
          subtitle: 'Les modules de l\'année n\'ont pas encore été publiés.',
        ),
      );
    }

    final theme = Theme.of(context);
    final mono = theme.extension<AppTypography>()!.monoFamily;
    final modules = semesters.expand((s) => s.unites).expand((u) => u.matieres).length;
    final credits = semesters
        .expand((s) => s.unites)
        .fold<double>(0, (sum, u) => sum + (u.credits ?? u.matieres.fold(0, (a, m) => a + (m.credits ?? 0))));

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        AppCard(
          accent: AppColors.purple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cleanFiliere(grades.filiere) ?? 'Programme de l\'année',
                style: theme.textTheme.titleMedium,
              ),
              if (grades.niveau != null)
                Text(
                  'Niveau ${grades.niveau}',
                  style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _Stat(value: '${semesters.length}', label: 'semestres', mono: mono),
                  _Stat(value: '$modules', label: 'modules', mono: mono),
                  if (credits > 0) _Stat(value: _num(credits), label: 'crédits', mono: mono),
                ],
              ),
            ],
          ),
        ),
        for (final s in semesters) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            s.label.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.c.textSecondary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final u in s.unites) ...[
            const SizedBox(height: AppSpacing.md),
            _UniteCard(unite: u),
          ],
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final String mono;

  const _Stat({required this.value, required this.label, required this.mono});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: mono, color: AppColors.purple),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.c.textMuted)),
          ],
        ),
      );
}

class _UniteCard extends StatelessWidget {
  final Unite unite;

  const _UniteCard({required this.unite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(unite.libelle.isEmpty ? 'Unité' : unite.libelle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (unite.coefficient != null)
                StatusBadge(label: 'Coef. ${_num(unite.coefficient!)}', color: AppColors.purple),
              if (unite.credits != null)
                StatusBadge(label: '${_num(unite.credits!)} crédits', color: AppColors.info),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < unite.matieres.length; i++) ...[
            const Divider(height: 1),
            _MatiereLine(matiere: unite.matieres[i]),
          ],
        ],
      ),
    );
  }
}

class _MatiereLine extends StatelessWidget {
  final Matiere matiere;

  const _MatiereLine({required this.matiere});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.extension<AppTypography>()!.monoFamily;
    final evals = matiere.epreuves.where((e) => e.libelle.isNotEmpty).map((e) {
      // Labels sometimes embed the weight ("DS (0.4)"); show it once, as a %.
      final name = e.libelle.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      final p = e.poids;
      if (p == null) return name;
      return '$name ${_num(p <= 1 ? p * 100 : p)} %';
    }).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(matiere.libelle, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (matiere.regime != null || evals.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [if (matiere.regime != null) matiere.regime!, if (evals.isNotEmpty) evals].join('  —  '),
                    style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (matiere.coefficient != null)
                Text(
                  'coef ${_num(matiere.coefficient!)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: mono, color: context.c.textSecondary),
                ),
              if (matiere.credits != null)
                Text(
                  '${_num(matiere.credits!)} cr.',
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: mono, color: context.c.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
