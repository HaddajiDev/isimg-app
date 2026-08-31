import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/core/moyenne_calculator.dart';
import 'package:isimg_app/models/grade_tree.dart';
import 'package:isimg_app/models/manual_note.dart';

const calc = MoyenneCalculator();

ManualNoteKey key(String matiere, int index) => ManualNoteKey(
      annee: '13',
      session: '1',
      semestre: '1',
      unite: 'Uef410',
      matiere: matiere,
      epreuveIndex: index,
    );

List<Semestre> tree(List<Matiere> matieres) => [
      Semestre(
        label: '1',
        unites: [Unite(libelle: 'Uef410', coefficient: 3, matieres: matieres)],
      ),
    ];

List<Semestre> merged(List<Semestre> semesters, ManualNotes notes) =>
    applyManualNotes(semesters: semesters, manual: notes, annee: '13', session: '1');

Matiere only(List<Semestre> semesters) => semesters.first.unites.first.matieres.first;

void main() {
  group('key', () {
    test('round-trips through its storage form', () {
      final original = key('Anglais 3', 2);
      final parsed = ManualNoteKey.tryParse(original.storageKey);
      expect(parsed, original);
      expect(parsed!.matiere, 'Anglais 3');
      expect(parsed.epreuveIndex, 2);
    });

    test('distinguishes identically-labelled épreuves by position', () {
      expect(key('Anglais 3', 0).storageKey, isNot(key('Anglais 3', 2).storageKey));
    });

    test('rejects malformed input', () {
      expect(ManualNoteKey.tryParse('nonsense'), isNull);
      expect(ManualNoteKey.tryParse('13§1§1§U§M§notanumber'), isNull);
    });
  });

  group('merge', () {
    test('fills a blank épreuve and flags it manual', () {
      final semesters = tree([
        const Matiere(
          libelle: 'Qualité',
          coefficient: 1.5,
          epreuves: [
            Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 9.5),
            Epreuve(libelle: 'Ex (0.7)', poids: 0.7),
          ],
        ),
      ]);

      final result = merged(semesters, ManualNotes.empty.set(key('Qualité', 1), 14));
      final epreuves = only(result).epreuves;

      expect(epreuves[1].note, 14);
      expect(epreuves[1].isManual, isTrue);

      expect(epreuves[0].note, 9.5);
      expect(epreuves[0].isManual, isFalse);
    });

    test('never overwrites a note published by the school', () {
      final semesters = tree([
        const Matiere(
          libelle: 'Qualité',
          coefficient: 1.5,
          epreuves: [Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 9.5)],
        ),
      ]);

      final result = merged(semesters, ManualNotes.empty.set(key('Qualité', 0), 20));
      expect(only(result).epreuves[0].note, 9.5);
      expect(only(result).epreuves[0].isManual, isFalse);
    });

    test('never overwrites a recorded absence', () {
      final semesters = tree([
        const Matiere(
          libelle: 'Vision',
          coefficient: 1.5,
          epreuves: [Epreuve(libelle: 'DS (0.15)', poids: 0.15, absent: true)],
        ),
      ]);

      final result = merged(semesters, ManualNotes.empty.set(key('Vision', 0), 18));
      expect(only(result).epreuves[0].absent, isTrue);
      expect(only(result).epreuves[0].note, isNull);
      expect(only(result).epreuves[0].isManual, isFalse);
    });

    test('leaves the tree untouched when nothing is stored', () {
      final semesters = tree([
        const Matiere(
          libelle: 'Qualité',
          epreuves: [Epreuve(libelle: 'Ex (0.7)', poids: 0.7)],
        ),
      ]);
      expect(merged(semesters, ManualNotes.empty), same(semesters));
    });

    test('ignores notes stored under a different année or session', () {
      final semesters = tree([
        const Matiere(
          libelle: 'Qualité',
          epreuves: [Epreuve(libelle: 'Ex (0.7)', poids: 0.7)],
        ),
      ]);

      final otherYear = ManualNotes.empty.set(
        const ManualNoteKey(
          annee: '12',
          session: '1',
          semestre: '1',
          unite: 'Uef410',
          matiere: 'Qualité',
          epreuveIndex: 0,
        ),
        14,
      );

      expect(only(merged(semesters, otherYear)).epreuves[0].note, isNull);
    });
  });

  group('store', () {
    test('adds, removes and counts per année/session', () {
      var notes = ManualNotes.empty
          .set(key('A', 0), 12)
          .set(key('B', 1), 14);
      expect(notes.length, 2);
      expect(notes.countFor(annee: '13', session: '1'), 2);
      expect(notes.countFor(annee: '12', session: '1'), 0);

      notes = notes.remove(key('A', 0));
      expect(notes.noteFor(key('A', 0)), isNull);
      expect(notes.noteFor(key('B', 1)), 14);

      notes = notes.clearFor(annee: '13', session: '1');
      expect(notes.isEmpty, isTrue);
    });

    test('clearFor spares other années', () {
      final notes = ManualNotes.empty.set(key('A', 0), 12).set(
            const ManualNoteKey(
              annee: '12',
              session: '1',
              semestre: '1',
              unite: 'U',
              matiere: 'M',
              epreuveIndex: 0,
            ),
            8,
          );
      final after = notes.clearFor(annee: '13', session: '1');
      expect(after.length, 1);
      expect(after.countFor(annee: '12', session: '1'), 1);
    });
  });

  group('averages built on manual notes', () {
    test('are reported as simulated, not as real results', () {
      final semesters = tree([
        const Matiere(
          libelle: 'Qualité',
          coefficient: 1.5,
          epreuves: [
            Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 10),
            Epreuve(libelle: 'Ex (0.7)', poids: 0.7),
          ],
        ),
      ]);

      final result = merged(semesters, ManualNotes.empty.set(key('Qualité', 1), 15));
      final average = calc.matiereAverage(only(result));

      expect(average.value, closeTo(13.5, 0.001));
      expect(average.source, AverageSource.simulated);
      expect(average.isSimulated, isTrue);
      expect(average.isEstimate, isTrue);
    });

    test('propagate the simulated marker up to the semester', () {
      final semesters = tree([
        const Matiere(
          libelle: 'Qualité',
          coefficient: 1.5,
          epreuves: [Epreuve(libelle: 'Ex (0.7)', poids: 0.7)],
        ),
      ]);

      final result = merged(semesters, ManualNotes.empty.set(key('Qualité', 0), 15));
      expect(calc.uniteAverage(result.first.unites.first).source, AverageSource.simulated);
      expect(calc.semestreAverage(result.first).source, AverageSource.simulated);
      expect(calc.annualAverage(result).source, AverageSource.simulated);
    });

    test('a single-semester year still yields an annual average', () {
      final semesters = tree([
        const Matiere(
          libelle: 'Qualité',
          coefficient: 1.5,
          epreuves: [Epreuve(libelle: 'Ex (0.7)', poids: 0.7, note: 12)],
        ),
      ]);
      expect(semesters.length, 1);
      expect(calc.annualAverage(semesters).value, closeTo(12, 0.001));
    });
  });
}
