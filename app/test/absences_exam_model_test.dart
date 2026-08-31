import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/models/absences.dart';
import 'package:isimg_app/models/exam.dart';

void main() {
  group('Absences.fromJson', () {
    Map<String, dynamic> record() => {
          'current_semestre': 1,
          'bilan_s1': {
            'tauxglobal': 3.2,
            'nbreglobal': 2,
            'elimglobal': '',
            'liste_absences': [
              {'date': '2026-03-04', 'seance': '2', 'type': 'Cours', 'prof': 'R. Abbes', 'module': 'Algo'},
            ],
            'matieres': [
              {'taux': 8, 'MatStatType': [{'nbre': 1, 'type': 'Cours'}, {'nbre': 1, 'type': 'TP'}], 'module': 'Algo', 'matid': '1', 'isElimine': false, 'elimine': ''},
              {'taux': 0, 'MatStatType': [{'nbre': 0, 'type': 'Cours'}], 'module': 'Base de données', 'matid': '2', 'isElimine': false, 'elimine': ''},
            ],
          },
          'bilan_s2': {'tauxglobal': 0, 'nbreglobal': 0, 'matieres': <dynamic>[]},
        };

    test('parses semesters, keeping only tracked ones', () {
      final a = Absences.fromJson(record());
      expect(a.currentSemestre, 1);

      expect(a.semesters.map((s) => s.semestre), [1]);
      expect(a.totalAbsences, 2);
    });

    test('parses per-matière tallies and the detailed list', () {
      final s1 = Absences.fromJson(record()).s1!;
      expect(s1.tauxGlobal, 3.2);
      expect(s1.matieres, hasLength(2));
      final algo = s1.matieres.first;
      expect(algo.module, 'Algo');
      expect(algo.total, 2);
      expect(algo.parType.map((t) => t.type), ['Cours', 'TP']);
      expect(s1.entries, hasLength(1));
      expect(s1.entries.first.module, 'Algo');
      expect(s1.entries.first.enseignant, 'R. Abbes');
    });

    test('round-trips through the cache', () {
      final original = Absences.fromJson(record());
      final restored = Absences.fromJson(original.toJson());
      expect(restored.totalAbsences, original.totalAbsences);
      expect(restored.s1!.matieres.first.total, 2);
      expect(restored.s1!.entries.first.date, '2026-03-04');
    });
  });

  group('Exam.fromJson', () {
    Map<String, dynamic> exam(Map<String, dynamic> over) => {
          'id': '5', 'module': 'Big Data', 'mid': '1249', 'duree': '90', 'type': '1',
          'classe_name': 'LSIM3', 'prof': 'S. Elji', 'debut': '2026-03-04 08:15:00',
          'salle': 'A6', 'eprv': '2', 'date': '2026-03-04', 'elim': '1',
          'horaire': '08:15 - 09:45', 'epreuve': 'DS', ...over,
        };

    test('maps the core fields and the DS type', () {
      final e = Exam.fromJson(exam({}));
      expect(e.matiere, 'Big Data');
      expect(e.type, ExamType.ds);
      expect(e.dureeMinutes, 90);
      expect(e.salle, 'A6');
      expect(e.enseignant, 'S. Elji');
      expect(e.eliminatoire, isTrue);
      expect(e.debut, DateTime(2026, 3, 4, 8, 15));
      expect(e.day, DateTime(2026, 3, 4));
    });

    test('type codes map correctly, including the 9/10/11 gap', () {
      expect(Exam.fromJson(exam({'type': '2'})).type, ExamType.examen);
      expect(Exam.fromJson(exam({'type': '4'})).type, ExamType.tp);
      expect(Exam.fromJson(exam({'type': '9'})).type, ExamType.autre);
      expect(Exam.fromJson(exam({'type': '10'})).type, ExamType.expose);
      expect(Exam.fromJson(exam({'type': '11'})).type, ExamType.exercice);
      expect(Exam.fromJson(exam({'type': '99'})).type, ExamType.autre);
    });

    test('null-sentinel dates become null, not epoch', () {
      expect(Exam.fromJson(exam({'debut': '0000-00-00 00:00:00', 'date': '0000-00-00'})).debut, isNull);
      expect(Exam.fromJson(exam({'debut': '0000-00-00 00:00:00', 'date': '0000-00-00'})).day, isNull);
    });

    test('salle falls back to abrev when salle is absent', () {
      final e = Exam.fromJson(exam({'salle': '', 'abrev': 'B2'}));
      expect(e.salle, 'B2');
    });

    test('type round-trips through the cache for the gapped codes', () {
      for (final t in [ExamType.ds, ExamType.autre, ExamType.expose, ExamType.exercice]) {
        final restored = Exam.fromJson(Exam(matiere: 'x', type: t).toJson());
        expect(restored.type, t, reason: t.name);
      }
    });

    test('ExamsSchedule round-trips and preserves order', () {
      final schedule = ExamsSchedule(exams: [
        Exam.fromJson(exam({'module': 'A', 'debut': '2026-03-04 08:15:00'})),
        Exam.fromJson(exam({'module': 'B', 'debut': '2026-03-06 11:30:00'})),
      ]);
      final restored = ExamsSchedule.fromJson(schedule.toJson());
      expect(restored.exams.map((e) => e.matiere), ['A', 'B']);
      expect(restored.hasExams, isTrue);
    });
  });
}
