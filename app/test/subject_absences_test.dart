import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/models/absences.dart';

void main() {
  final absences = Absences(
    currentSemestre: 2,
    s1: const SemestreAbsences(
      semestre: 1,
      nbreGlobal: 1,
      entries: [AbsenceEntry(date: '2026-01-10', seance: '1', type: 'Cours', module: 'Sécurité Web')],
      matieres: [
        MatiereAbsence(module: 'Sécurité Web', taux: 5, parType: [TypeAbsence(type: 'Cours', nbre: 1)]),
      ],
    ),
    s2: const SemestreAbsences(
      semestre: 2,
      nbreGlobal: 3,
      entries: [
        AbsenceEntry(date: '2026-03-02', seance: '3', type: 'TP', module: 'Sécurité web'),
        AbsenceEntry(date: '2026-03-09', seance: '2', type: 'Cours', module: 'Sécurité web'),
        AbsenceEntry(date: '2026-03-09', seance: '1', type: 'TD', module: 'Big Data'),
      ],
      matieres: [
        MatiereAbsence(module: 'Sécurité web', taux: 12.5, parType: [TypeAbsence(type: 'Cours', nbre: 2)]),
        MatiereAbsence(module: 'Big Data', taux: 4, parType: [TypeAbsence(type: 'TD', nbre: 1)]),
        MatiereAbsence(module: 'Anglais 5', taux: 0),
      ],
    ),
    matiereThreshold: 20,
  );

  test('matches ignoring case and accents, preferring the current semester', () {
    final s = absences.forSubject('SECURITE WEB');
    expect(s.isTracked, isTrue);
    expect(s.stats?.taux, 12.5);
    expect(s.count, 2);
    expect(s.threshold, 20);
  });

  test('lists every dated absence for the subject, newest first', () {
    final s = absences.forSubject('Sécurité web');
    expect(s.entries.map((e) => e.date), ['2026-03-09', '2026-03-02', '2026-01-10']);
  });

  test('a subject with no absence is tracked with a zero count', () {
    final s = absences.forSubject('Anglais 5');
    expect(s.isTracked, isTrue);
    expect(s.count, 0);
    expect(s.entries, isEmpty);
  });

  test('an unknown or too-short name is not matched by accident', () {
    expect(absences.forSubject('Maillage').isTracked, isFalse);
    expect(absences.forSubject('Big').isTracked, isFalse);
  });
}
