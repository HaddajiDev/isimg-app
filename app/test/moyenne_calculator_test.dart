import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/core/moyenne_calculator.dart';
import 'package:isimg_app/models/grade_tree.dart';

const calc = MoyenneCalculator();

Matiere matiere({
  double? moyenne,
  double? coefficient = 1.5,
  List<Epreuve> epreuves = const [],
}) {
  return Matiere(
    libelle: 'Matière',
    coefficient: coefficient,
    moyenne: moyenne,
    epreuves: epreuves,
  );
}

void main() {
  group('matière', () {
    test('prefers the published average over any computation', () {
      final m = matiere(
        moyenne: 6.5,
        epreuves: const [
          Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 20),
          Epreuve(libelle: 'Ex (0.7)', poids: 0.7, note: 20),
        ],
      );
      final result = calc.matiereAverage(m);
      expect(result.value, 6.5);
      expect(result.source, AverageSource.official);
      expect(result.isEstimate, isFalse);
    });

    test('computes DS/Ex weighting when the average is missing', () {
      final result = calc.matiereAverage(
        matiere(
          epreuves: const [
            Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 10),
            Epreuve(libelle: 'Ex (0.7)', poids: 0.7, note: 5),
          ],
        ),
      );
      expect(result.value, closeTo(6.5, 0.001));
      expect(result.source, AverageSource.computed);
    });

    test('computes DS/TP/Ex weighting', () {
      final result = calc.matiereAverage(
        matiere(
          epreuves: const [
            Epreuve(libelle: 'DS (0.15)', poids: 0.15, note: 15.5),
            Epreuve(libelle: 'TP (0.15)', poids: 0.15, note: 18),
            Epreuve(libelle: 'Ex (0.7)', poids: 0.7, note: 17),
          ],
        ),
      );
      expect(result.value, closeTo(16.925, 0.001));
      expect(result.source, AverageSource.computed);
    });

    test('renormalises over graded épreuves only, and flags it partial', () {
      final result = calc.matiereAverage(
        matiere(
          epreuves: const [
            Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 12),
            Epreuve(libelle: 'Ex (0.7)', poids: 0.7),
          ],
        ),
      );
      expect(result.value, closeTo(12, 0.001));
      expect(result.source, AverageSource.partial);
      expect(result.isEstimate, isTrue);
    });

    test('is unavailable when no note has been posted', () {
      final result = calc.matiereAverage(
        matiere(
          epreuves: const [
            Epreuve(libelle: 'DS (0.3)', poids: 0.3),
            Epreuve(libelle: 'Ex (0.7)', poids: 0.7),
          ],
        ),
      );
      expect(result.hasValue, isFalse);
      expect(result.source, AverageSource.unavailable);
    });

    test('scores an absence as zero rather than treating it as pending', () {
      final result = calc.matiereAverage(
        matiere(
          epreuves: const [
            Epreuve(libelle: 'DS (0.15)', poids: 0.15, note: 0.5),
            Epreuve(libelle: 'TP (0.15)', poids: 0.15, absent: true),
            Epreuve(libelle: 'Ex (0.7)', poids: 0.7, absent: true),
          ],
        ),
      );
      expect(result.value, closeTo(0.075, 0.001));

      expect(result.source, AverageSource.computed);
    });

    test('separates an absence from a mark that has not been entered', () {
      final pending = calc.matiereAverage(
        matiere(
          epreuves: const [
            Epreuve(libelle: 'DS (0.15)', poids: 0.15, note: 0.5),
            Epreuve(libelle: 'Ex (0.7)', poids: 0.7),
          ],
        ),
      );
      expect(pending.value, closeTo(0.5, 0.001));
      expect(pending.source, AverageSource.partial);
    });

    test('refuses to guess once a rattrapage épreuve appears', () {
      final result = calc.matiereAverage(
        matiere(
          epreuves: const [
            Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 10),
            Epreuve(libelle: 'Ex (0.7)', poids: 0.7, note: 5),
            Epreuve(libelle: 'Rex (0.7)', poids: 0.7, note: 2.5),
          ],
        ),
      );
      expect(result.hasValue, isFalse);
    });
  });

  group('unité', () {
    test('weights matières by their coefficient', () {
      final unite = Unite(
        libelle: 'Uef110',
        coefficient: 3,
        matieres: [
          matiere(moyenne: 6.5),
          matiere(moyenne: 5.35),
        ],
      );
      final result = calc.uniteAverage(unite);
      expect(result.value, closeTo(5.925, 0.001));
    });

    test('respects unequal coefficients', () {
      final unite = Unite(
        libelle: 'U',
        matieres: [
          matiere(moyenne: 12, coefficient: 2),
          matiere(moyenne: 6, coefficient: 1),
        ],
      );
      expect(calc.uniteAverage(unite).value, closeTo(10, 0.001));
    });

    test('skips matières with no average instead of counting them as zero', () {
      final unite = Unite(
        libelle: 'U',
        matieres: [
          matiere(moyenne: 12, coefficient: 2),
          matiere(coefficient: 3),
        ],
      );
      expect(calc.uniteAverage(unite).value, closeTo(12, 0.001));
    });

    test('an estimated matière makes the unité an estimate too', () {
      final unite = Unite(
        libelle: 'U',
        matieres: [
          matiere(
            epreuves: const [
              Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 12),
              Epreuve(libelle: 'Ex (0.7)', poids: 0.7),
            ],
          ),
        ],
      );
      expect(calc.uniteAverage(unite).source, AverageSource.partial);
    });
  });

  group('semestre and année', () {
    final s1 = Semestre(
      label: '1',
      unites: [
        Unite(libelle: 'Uef110', coefficient: 3, moyenne: 7.63),
        Unite(libelle: 'Uef120', coefficient: 3.5, moyenne: 12.12),
        Unite(libelle: 'Uef130', coefficient: 3.5, moyenne: 10.25),
        Unite(libelle: 'Uef140', coefficient: 3, moyenne: 9.43),
        Unite(libelle: 'Uet110', coefficient: 2, moyenne: 11.4),
      ],
    );
    final s2 = Semestre(
      label: '2',
      unites: [
        Unite(libelle: 'Uef210', coefficient: 3, moyenne: 14.5),
        Unite(libelle: 'Uef220', coefficient: 3.5, moyenne: 10.78),
        Unite(libelle: 'Uef230', coefficient: 3.5, moyenne: 9.02),
        Unite(libelle: 'Uef240', coefficient: 2, moyenne: 13),
        Unite(libelle: 'Uet210', coefficient: 3, moyenne: 8.53),
      ],
    );

    test('weights unités by their coefficient', () {
      expect(calc.semestreAverage(s1).value, closeTo(10.15, 0.01));
      expect(calc.semestreAverage(s2).value, closeTo(10.96, 0.01));
      expect(calc.semestreAverage(s1).source, AverageSource.official);
    });

    test('annual average reproduces the published moyenne générale', () {
      expect(calc.annualAverage([s1, s2]).value, closeTo(10.56, 0.01));
    });

    test('ignores semesters that have nothing computable', () {
      final empty = Semestre(label: '2', unites: [Unite(libelle: 'U', coefficient: 1)]);
      expect(calc.annualAverage([s1, empty]).value, closeTo(10.15, 0.01));
    });

    test('end-to-end: recomputes a whole bulletin from raw notes alone', () {
      final unite = Unite(
        libelle: 'Uef110',
        coefficient: 3,
        matieres: const [
          Matiere(
            libelle: 'Algèbre 1',
            coefficient: 1.5,
            epreuves: [
              Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 10),
              Epreuve(libelle: 'Ex (0.7)', poids: 0.7, note: 5),
            ],
          ),
          Matiere(
            libelle: 'Analyse 1',
            coefficient: 1.5,
            epreuves: [
              Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 5),
              Epreuve(libelle: 'Ex (0.7)', poids: 0.7, note: 5.5),
            ],
          ),
        ],
      );

      final result = calc.uniteAverage(unite);
      expect(result.value, closeTo(5.925, 0.001));

      expect(result.source, AverageSource.computed);
      expect(result.isEstimate, isTrue);
    });

    test('is unavailable with no data at all', () {
      expect(calc.annualAverage([]).hasValue, isFalse);
      expect(calc.annualAverage([const Semestre(label: '1')]).hasValue, isFalse);
    });
  });
}
