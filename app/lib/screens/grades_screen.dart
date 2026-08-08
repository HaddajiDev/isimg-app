import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../core/moyenne_calculator.dart';
import '../models/grade_tree.dart';
import '../models/grades.dart';
import '../models/manual_note.dart';
import '../providers/auth_provider.dart';
import '../providers/grades_provider.dart';
import '../providers/manual_notes_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/average_chip.dart';
import '../widgets/manual_note_sheet.dart';
import '../widgets/state_views.dart';
import '../widgets/student_avatar.dart';

const _calc = MoyenneCalculator();

/// First letters of the first two words, e.g. "Haddaji Ahmed" -> "HA".
String _initialsOf(String? name) {
  final words = (name ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.map((w) => w[0].toUpperCase()).take(2).join();
}

class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(gradesProvider);

    return gradesAsync.when(
      loading: () => const _GradesSkeleton(),
      error: (error, _) {
        if (error is ApiException && error.isSessionExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(authProvider.notifier).handleSessionExpired();
          });
        }
        return MessageView(
          icon: Icons.cloud_off_rounded,
          title: 'Impossible de charger les notes',
          subtitle: error is ApiException ? error.code : 'Vérifiez votre connexion.',
          tint: AppColors.danger,
          action: FilledButton(
            onPressed: () => ref.invalidate(gradesProvider),
            child: const Text('Réessayer'),
          ),
        );
      },
      data: (grades) {
        final annee = effectiveCode(
              ref.watch(selectedAuProvider),
              grades.currentAu,
              grades.annees,
            ) ??
            '';
        final session = effectiveCode(
              ref.watch(selectedSsProvider),
              grades.currentSs,
              grades.sessions,
            ) ??
            '';
        final manual = ref.watch(manualNotesProvider).value ?? ManualNotes.empty;

        // Student projections are layered on top of the fetched data; they can
        // only fill slots the school left blank.
        final semesters = applyManualNotes(
          semesters: grades.semesters,
          manual: manual,
          annee: annee,
          session: session,
        );

        final hasEstimates = _containsEstimate(semesters);
        final manualCount = manual.countFor(annee: annee, session: session);

        return RefreshIndicator(
          onRefresh: () => ref.refresh(gradesProvider.future),
          color: AppColors.purple,
          backgroundColor: AppColors.surfaceRaised,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              _FilterBar(grades: grades),
              const SizedBox(height: AppSpacing.lg),
              _SummaryCard(grades: grades, semesters: semesters),
              if (hasEstimates) ...[
                const SizedBox(height: AppSpacing.md),
                const EstimateLegend(),
              ],
              if (manualCount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                _ManualNotesBanner(
                  count: manualCount,
                  onClear: () => ref
                      .read(manualNotesProvider.notifier)
                      .clearFor(annee: annee, session: session),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (semesters.isEmpty)
                const AppCard(
                  child: SizedBox(
                    height: 180,
                    child: MessageView(
                      icon: Icons.inbox_rounded,
                      title: 'Aucun relevé',
                      subtitle: 'Pas de notes pour cette année/session.',
                    ),
                  ),
                )
              else
                for (final semestre in semesters)
                  _SemesterSection(
                    semestre: semestre,
                    annee: annee,
                    session: session,
                  ),
            ],
          ),
        );
      },
    );
  }

  static bool _containsEstimate(List<Semestre> semesters) {
    for (final semestre in semesters) {
      if (_calc.semestreAverage(semestre).isEstimate) return true;
      for (final unite in semestre.unites) {
        if (_calc.uniteAverage(unite).isEstimate) return true;
        for (final matiere in unite.matieres) {
          if (_calc.matiereAverage(matiere).isEstimate) return true;
        }
      }
    }
    return false;
  }
}

class _SemesterSection extends StatelessWidget {
  final Semestre semestre;
  final String annee;
  final String session;

  const _SemesterSection({
    required this.semestre,
    required this.annee,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final average = _calc.semestreAverage(semestre);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.md,
            left: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Text(
                'Semestre ${semestre.label}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              AverageChip(average: average, fontSize: 14),
            ],
          ),
        ),
        for (final unite in semestre.unites)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _UniteCard(
              unite: unite,
              semestre: semestre,
              annee: annee,
              session: session,
            ),
          ),
      ],
    );
  }
}

class _UniteCard extends StatelessWidget {
  final Unite unite;
  final Semestre semestre;
  final String annee;
  final String session;

  const _UniteCard({
    required this.unite,
    required this.semestre,
    required this.annee,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = _calc.uniteAverage(unite);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unite.libelle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        [
                          if (unite.credits != null) '${_trim(unite.credits!)} crédits',
                          if (unite.coefficient != null) 'coef. ${_trim(unite.coefficient!)}',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AverageChip(average: average),
              ],
            ),
          ),
          const Divider(),
          for (final matiere in unite.matieres)
            _MatiereRow(
              matiere: matiere,
              unite: unite,
              semestre: semestre,
              annee: annee,
              session: session,
            ),
        ],
      ),
    );
  }
}

class _MatiereRow extends ConsumerWidget {
  final Matiere matiere;
  final Unite unite;
  final Semestre semestre;
  final String annee;
  final String session;

  const _MatiereRow({
    required this.matiere,
    required this.unite,
    required this.semestre,
    required this.annee,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mono = theme.extension<AppTypography>()!.monoFamily;
    final average = _calc.matiereAverage(matiere);
    final color = AverageChip.colorFor(average);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(matiere.libelle, style: theme.textTheme.bodyLarge),
                    if (matiere.coefficient != null || matiere.regime != null)
                      Text(
                        [
                          if (matiere.regime != null) matiere.regime!,
                          if (matiere.coefficient != null)
                            'coef. ${_trim(matiere.coefficient!)}',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AverageChip(average: average, fontSize: 18, boxed: false),
            ],
          ),
          if (matiere.epreuves.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var i = 0; i < matiere.epreuves.length; i++)
                    _EpreuveChip(
                      epreuve: matiere.epreuves[i],
                      monoFamily: mono,
                      // Only slots the school hasn't filled can be simulated.
                      onEdit: matiere.epreuves[i].isEditable
                          ? () => _editNote(context, ref, i)
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref, int index) async {
    final epreuve = matiere.epreuves[index];
    final key = manualKeyFor(
      annee: annee,
      session: session,
      semestre: semestre,
      unite: unite,
      matiere: matiere,
      epreuveIndex: index,
    );

    final result = await showManualNoteSheet(
      context,
      matiere: matiere.libelle,
      epreuve: epreuve.libelle,
      existing: epreuve.isManual ? epreuve.note : null,
    );
    if (result == null) return;

    final notifier = ref.read(manualNotesProvider.notifier);
    switch (result) {
      case ManualNoteSaved(note: final note):
        await notifier.setNote(key, note);
      case ManualNoteDeleted():
        await notifier.removeNote(key);
    }
  }
}

class _EpreuveChip extends StatelessWidget {
  final Epreuve epreuve;
  final String monoFamily;
  final VoidCallback? onEdit;

  const _EpreuveChip({
    required this.epreuve,
    required this.monoFamily,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (epreuve) {
      // An absence is a scored zero, so it earns the failing colour rather
      // than looking like a mark that has yet to arrive.
      Epreuve(absent: true) => ('Abs.', AppColors.danger),
      Epreuve(isManual: true, note: final note?) => (_trim(note), AppColors.purple),
      Epreuve(note: final note?) => (_trim(note), AppColors.textPrimary),
      _ => ('–', AppColors.textMuted),
    };

    final isManual = epreuve.isManual;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      constraints: const BoxConstraints(minHeight: 30),
      decoration: BoxDecoration(
        color: isManual ? AppColors.purple.withValues(alpha: 0.10) : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isManual ? AppColors.purple.withValues(alpha: 0.55) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            epreuve.libelle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: TextStyle(
              fontFamily: monoFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          // Only ungraded slots invite input, so the affordance appears there.
          if (onEdit != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              isManual ? Icons.edit_rounded : Icons.add_rounded,
              size: 13,
              color: isManual ? AppColors.purple : AppColors.textMuted,
            ),
          ],
        ],
      ),
    );

    if (onEdit == null) return chip;

    return Semantics(
      button: true,
      label: isManual
          ? 'Modifier la note provisoire de ${epreuve.libelle}'
          : 'Ajouter une note provisoire pour ${epreuve.libelle}',
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: chip,
      ),
    );
  }
}

/// Summarises how many projections are active and offers a single undo.
class _ManualNotesBanner extends StatelessWidget {
  final int count;
  final VoidCallback onClear;

  const _ManualNotesBanner({required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, size: 16, color: AppColors.purple),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              count == 1
                  ? '1 note provisoire — simulation'
                  : '$count notes provisoires — simulation',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.purple,
              minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final Grades grades;

  const _FilterBar({required this.grades});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auPick = ref.watch(selectedAuProvider);
    final ssPick = ref.watch(selectedSsProvider);
    final currentAu = effectiveCode(auPick, grades.currentAu, grades.annees);
    final currentSs = effectiveCode(ssPick, grades.currentSs, grades.sessions);

    // Both codes are pinned on any change: the upstream form only honours
    // f_au and f_ss when they arrive together.
    void select({String? au, String? ss}) {
      ref.read(selectedAuProvider.notifier).state = au ?? currentAu;
      ref.read(selectedSsProvider.notifier).state = ss ?? currentSs;
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _OptionDropdown(
            icon: Icons.calendar_today_rounded,
            value: currentAu,
            options: grades.annees,
            onChanged: (code) => select(au: code),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: _OptionDropdown(
            icon: Icons.layers_rounded,
            value: currentSs,
            options: grades.sessions,
            onChanged: (code) => select(ss: code),
          ),
        ),
      ],
    );
  }
}

class _OptionDropdown extends StatelessWidget {
  final IconData icon;
  final String? value;
  final List<SelectOption> options;
  final ValueChanged<String?> onChanged;

  const _OptionDropdown({
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Container(
      height: kMinTouchTarget + 6,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.purple),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(AppRadius.md),
                dropdownColor: AppColors.surfaceRaised,
                icon: const Icon(Icons.expand_more_rounded, size: 20),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                items: options
                    .map((option) => DropdownMenuItem(
                          value: option.code,
                          child: Text(option.label, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Grades grades;
  final List<Semestre> semesters;

  const _SummaryCard({required this.grades, required this.semesters});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The published moyenne wins; otherwise fall back to our own computation
    // so students see a running estimate during the year.
    final official = double.tryParse(grades.moyenneGenerale ?? '');
    final average = official != null
        ? Average(official, AverageSource.official)
        : _calc.annualAverage(semesters);
    final accent = AverageChip.colorFor(average);

    return AppCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudentAvatar(
                seed: grades.nom ?? '',
                initials: _initialsOf(grades.nom),
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grades.nom ?? '—',
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Niveau ${grades.niveau ?? '—'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (grades.filiere != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              grades.filiere!,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: average.isEstimate ? 'Moyenne (est.)' : 'Moyenne',
                  average: average,
                ),
              ),
              Expanded(
                child: _StatTile(label: 'Crédits', text: grades.credits ?? '—'),
              ),
              Expanded(
                child: _StatTile(label: 'Rang', text: grades.rang ?? '—'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String? text;
  final Average? average;

  const _StatTile({required this.label, this.text, this.average});

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).extension<AppTypography>()!.monoFamily;

    return Column(
      children: [
        if (average != null)
          AverageChip(average: average!, fontSize: 26, boxed: false)
        else
          Text(
            text ?? '—',
            style: TextStyle(
              fontFamily: mono,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Drops a trailing ".0" so coefficients read "3" and "1.5".
String _trim(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

class _GradesSkeleton extends StatelessWidget {
  const _GradesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: const [
            Expanded(flex: 3, child: SkeletonBox(height: 50)),
            SizedBox(width: AppSpacing.sm),
            Expanded(flex: 2, child: SkeletonBox(height: 50)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonBox(height: 190),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < 3; i++) ...[
          const SkeletonBox(height: 140),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
