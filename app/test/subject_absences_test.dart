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

  test('an unknown name is not matched by accident', () {
    expect(absences.forSubject('Maillage').isTracked, isFalse);
    expect(absences.forSubject('Data Mining').isTracked, isFalse);
  });

  group('timetable short names against official module names', () {
    const official = [
      'Anglais 5',
      'Architecture soa et service web',
      "Développement d'applications web et multimédia(J2EE, .NET..)",
      'Entreprenariat',
      'Framework & technologies big data',
      'Machine Learning',
      'Maillage 2D-3D',
      "Préparation à l'environnement professionnel",
      'Réalité virtuelle et réalité augmentée',
      'Sécurité web',
      "Techniques d'indexation et de référencement",
      'Virtualisation et cloud',
    ];
    final real = Absences(
      currentSemestre: 1,
      s1: SemestreAbsences(
        semestre: 1,
        matieres: [for (final m in official) MatiereAbsence(module: m, taux: 0)],
      ),
    );

    String? matched(String short) => real.forSubject(short).stats?.module;

    test('every subject on the week resolves to its module', () {
      expect(matched('ML'), 'Machine Learning');
      expect(matched('SOA'), 'Architecture soa et service web');
      expect(matched('J2EE'), "Développement d'applications web et multimédia(J2EE, .NET..)");
      expect(matched('Anglais5'), 'Anglais 5');
      expect(matched('Préparation'), "Préparation à l'environnement professionnel");
      expect(matched('Indexation'), "Techniques d'indexation et de référencement");
      expect(matched('Maillage'), 'Maillage 2D-3D');
      expect(matched('Big Data'), 'Framework & technologies big data');
      expect(matched('Virtualisation'), 'Virtualisation et cloud');
      expect(matched('Virtuelle'), 'Réalité virtuelle et réalité augmentée');
      expect(matched('Sécurité web'), 'Sécurité web');
      expect(matched('Entreprenariat'), 'Entreprenariat');
    });

    test('a leftover teacher word does not block the match', () {
      expect(matched('Préparation Karim'), "Préparation à l'environnement professionnel");
    });

    test('an ambiguous name matches nothing rather than guessing', () {
      expect(matched('Web'), isNull);
    });
  });
}
