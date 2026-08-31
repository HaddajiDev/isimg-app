import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/absences.dart';
import '../providers/absences_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/state_views.dart';

class AbsencesScreen extends ConsumerWidget {
  const AbsencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absencesAsync = ref.watch(absencesProvider);

    return absencesAsync.when(
      loading: () => const _AbsencesLoadingPlaceholder(),
      error: (error, _) {
        if (error is ApiException && error.isSessionExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(authProvider.notifier).handleSessionExpired();
          });
        }
        final offline = error is ApiException && error.isConnectivityProblem;
        return MessageView(
          icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
          title: offline ? 'Pas de connexion' : 'Impossible de charger les absences',
          subtitle: offline
              ? 'Vos absences n\'ont pas encore été enregistrées hors ligne.'
              : (error is ApiException ? error.code : 'Vérifiez votre connexion.'),
          tint: AppColors.danger,
          action: FilledButton(
            onPressed: () => ref.invalidate(absencesProvider),
            child: const Text('Réessayer'),
          ),
        );
      },
      data: (view) => Column(
        children: [
          if (view.capturedAt case final capturedAt?) OfflineBanner(capturedAt: capturedAt),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(absencesProvider.future),
              color: AppColors.purple,
              backgroundColor: AppColors.surfaceRaised,
              child: _AbsencesContent(absences: view.absences),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbsencesLoadingPlaceholder extends ConsumerWidget {
  const _AbsencesLoadingPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peeked = ref.watch(absencesCachePeekProvider);
    return peeked.when(
      data: (cached) => cached == null
          ? const _AbsencesSkeleton()
          : Stack(
              children: [
                _AbsencesContent(absences: cached.absences),
                const _TopProgress(),
              ],
            ),
      loading: () => const _AbsencesSkeleton(),
      error: (_, _) => const _AbsencesSkeleton(),
    );
  }
}

class _AbsencesContent extends StatelessWidget {
  final Absences absences;

  const _AbsencesContent({required this.absences});

  @override
  Widget build(BuildContext context) {
    final semesters = absences.semesters;

    if (semesters.isEmpty) {
      return _scrollableEmpty(
        const MessageView(
          icon: Icons.fact_check_outlined,
          title: 'Aucun suivi d\'absence',
          subtitle: 'Rien n\'est encore enregistré pour cette année.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _HeroSummary(absences: absences),
        const SizedBox(height: AppSpacing.md),
        _ThresholdCaption(matiere: absences.matiereThreshold, global: absences.globalThreshold),
        const SizedBox(height: AppSpacing.lg),
        for (final sem in semesters) ...[
          _SemesterCard(
            semestre: sem,
            isCurrent: sem.semestre == absences.currentSemestre,
            matiereThreshold: absences.matiereThreshold,
            globalThreshold: absences.globalThreshold,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  static Widget _scrollableEmpty(Widget child) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      );
}

class _HeroSummary extends StatelessWidget {
  final Absences absences;

  const _HeroSummary({required this.absences});

  @override
  Widget build(BuildContext context) {
    final total = absences.totalAbsences;
    final clean = total == 0;
    final accent = clean ? AppColors.green : AppColors.warning;
    final mono = Theme.of(context).extension<AppTypography>()!.monoFamily;

    final current = absences.semesters
        .where((s) => s.semestre == absences.currentSemestre)
        .cast<SemestreAbsences?>()
        .firstWhere((_) => true, orElse: () => absences.semesters.isEmpty ? null : absences.semesters.first);

    return AppCard(
      accent: accent,
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(
              clean ? Icons.verified_rounded : Icons.event_busy_rounded,
              color: accent,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clean ? 'Aucune absence' : '$total absence${total > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: mono,
                        color: clean ? AppColors.textPrimary : accent,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  clean
                      ? 'Assiduité parfaite cette année. Continuez !'
                      : 'Sur l\'ensemble de l\'année universitaire.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          if (current != null) ...[
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_fmtPct(current.tauxGlobal ?? 0)} %',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: mono,
                        color: accent,
                      ),
                ),
                Text(
                  'taux global',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _fmtPct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class _ThresholdCaption extends StatelessWidget {
  final double matiere;
  final double global;

  const _ThresholdCaption({required this.matiere, required this.global});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Seuil d\'élimination — matière ${_fmtPct(matiere)} % · global ${_fmtPct(global)} %',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _SemesterCard extends StatelessWidget {
  final SemestreAbsences semestre;
  final bool isCurrent;
  final double matiereThreshold;
  final double globalThreshold;

  const _SemesterCard({
    required this.semestre,
    required this.isCurrent,
    required this.matiereThreshold,
    required this.globalThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).extension<AppTypography>()!.monoFamily;
    final severity = _severity(semestre, globalThreshold, matiereThreshold);

    final matieres = [...semestre.matieres]..sort((a, b) {
        final byCount = b.total.compareTo(a.total);
        if (byCount != 0) return byCount;
        return (b.taux ?? 0).compareTo(a.taux ?? 0);
      });

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Semestre ${semestre.semestre}', style: Theme.of(context).textTheme.titleMedium),
              if (isCurrent) ...[
                const SizedBox(width: AppSpacing.sm),
                const _Tag(label: 'En cours', color: AppColors.purple),
              ],
              const Spacer(),
              Text(
                '${semestre.nbreGlobal} abs.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: mono,
                      color: semestre.isClean ? AppColors.textMuted : severity,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _RateBar(
            label: 'Taux global',
            taux: semestre.tauxGlobal ?? 0,
            threshold: globalThreshold,
            color: severity,
          ),
          if (matieres.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Par matière',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final m in matieres) _MatiereRow(matiere: m, threshold: matiereThreshold),
          ],
        ],
      ),
    );
  }

  static Color _severity(SemestreAbsences s, double globalThreshold, double matiereThreshold) {
    final taux = s.tauxGlobal ?? 0;
    if (s.matieres.any((m) => m.eliminated || (m.taux ?? 0) >= matiereThreshold) ||
        taux >= globalThreshold) {
      return AppColors.danger;
    }
    if (taux >= globalThreshold * 0.66) return AppColors.warning;
    if (s.nbreGlobal == 0) return AppColors.green;
    return AppColors.info;
  }
}

class _RateBar extends StatelessWidget {
  final String label;
  final double taux;
  final double threshold;
  final Color color;

  const _RateBar({
    required this.label,
    required this.taux,
    required this.threshold,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).extension<AppTypography>()!.monoFamily;

    final maxScale = threshold <= 0 ? 100.0 : threshold / 0.7;
    final fraction = (taux / maxScale).clamp(0.0, 1.0);
    final markerAt = (threshold / maxScale).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '· seuil ${_fmtPct(threshold)} %',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const Spacer(),
            Text(
              '${_fmtPct(taux)} %',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: mono,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: 8,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Stack(
                    children: [
                      Container(height: 8, color: AppColors.surfaceRaised),
                      FractionallySizedBox(
                        widthFactor: fraction == 0 ? 0.02 : fraction,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  left: constraints.maxWidth * markerAt - 1,
                  child: Container(width: 2, height: 8, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MatiereRow extends StatelessWidget {
  final MatiereAbsence matiere;
  final double threshold;

  const _MatiereRow({required this.matiere, required this.threshold});

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).extension<AppTypography>()!.monoFamily;
    final active = matiere.parType.where((t) => t.nbre > 0).toList();
    final hasAbsences = matiere.total > 0;
    final tauxColor = _tauxColor(matiere, threshold);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  color: hasAbsences ? tauxColor : AppColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  matiere.module,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              Text(
                '${_fmtTaux(matiere.taux)} %',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: mono,
                      color: tauxColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 4),
            child: Row(
              children: [
                Text(
                  hasAbsences
                      ? '${matiere.total} absence${matiere.total > 1 ? 's' : ''}'
                      : 'Aucune absence',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hasAbsences ? AppColors.textSecondary : AppColors.textMuted,
                      ),
                ),
                if (active.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [for (final t in active) _TypeCountChip(type: t.type, nbre: t.nbre)],
                    ),
                  ),
                ] else
                  const Spacer(),

                if (matiere.eliminated)
                  _Tag(label: matiere.elimineLabel ?? 'Éliminé', color: AppColors.danger)
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.green),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Non éliminé',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTaux(double? taux) => _fmtPct(taux ?? 0);

  static Color _tauxColor(MatiereAbsence m, double threshold) {
    if (m.eliminated || (m.taux ?? 0) >= threshold) return AppColors.danger;
    if ((m.taux ?? 0) >= threshold * 0.5) return AppColors.warning;
    if (m.total == 0) return AppColors.green;
    return AppColors.info;
  }
}

class _TypeCountChip extends StatelessWidget {
  final String type;
  final int nbre;

  const _TypeCountChip({required this.type, required this.nbre});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$nbre $type',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Color _typeColor(String type) {
  switch (type.toLowerCase()) {
    case 'cours':
      return AppColors.warning;
    case 'td':
      return AppColors.info;
    case 'tp':
      return AppColors.green;
    default:
      return AppColors.textSecondary;
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _TopProgress extends StatelessWidget {
  const _TopProgress();

  @override
  Widget build(BuildContext context) => const Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: LinearProgressIndicator(
          minHeight: 2,
          color: AppColors.purple,
          backgroundColor: Colors.transparent,
        ),
      );
}

class _AbsencesSkeleton extends StatelessWidget {
  const _AbsencesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: const [
        SkeletonBox(height: 88, width: double.infinity),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(height: 180, width: double.infinity),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 140, width: double.infinity),
      ],
    );
  }
}
