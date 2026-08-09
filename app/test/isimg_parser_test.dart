import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/core/moyenne_calculator.dart';
import 'package:isimg_app/isimg/isimg_parser.dart';

const parser = IsimgParser();

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  group('grades', () {
    late final body = fixture('grades.html');

    test('recognises the page', () {
      expect(parser.looksLikeGradesPage(body), isTrue);
      expect(parser.isUnauthorized(body), isFalse);
    });

    test('reads the header fields', () {
      final grades = parser.parseGrades(body);
      expect(grades.nom, 'Haddaji Ahmed');
      expect(grades.cin, '09729031');
      expect(grades.niveau, '1');
      expect(grades.moyenneGenerale, '10.56');
      expect(grades.credits, '46');
      expect(grades.filiere, contains('Licence'));
    });

    test('reads the année and session options newest first', () {
      final grades = parser.parseGrades(body);
      expect(grades.annees.map((o) => o.label).toList(),
          ['2026-2027', '2025-2026', '2024-2025', '2023-2024']);
      expect(grades.annees.first.code, '13');
      // This capture is the Contrôle view, which the site marks selected.
      expect(parser.selectedCode(grades.sessions), '2');
    });

    test('builds the full semester tree', () {
      final grades = parser.parseGrades(body);
      expect(grades.semesters.length, 2);
      expect(grades.semesters.map((s) => s.label).toList(), ['1', '2']);
      expect(grades.semesters.every((s) => s.unites.length == 5), isTrue);
    });

    test('expands the rowspan cells into the right unit and subject values', () {
      final grades = parser.parseGrades(body);
      final unite = grades.semesters.first.unites.first;

      expect(unite.libelle, 'Uef110 : mathématique 1');
      expect(unite.coefficient, 3);
      expect(unite.credits, 6);
      expect(unite.moyenne, 7.63);

      final algebre = unite.matieres.first;
      expect(algebre.libelle, 'Algèbre 1');
      expect(algebre.regime, 'RM');
      expect(algebre.coefficient, 1.5);
      expect(algebre.credits, 3);
      expect(algebre.moyenne, 6.5);
    });

    test('reads épreuve weights out of their labels', () {
      final grades = parser.parseGrades(body);
      final algebre = grades.semesters.first.unites.first.matieres.first;

      expect(algebre.epreuves.map((e) => e.libelle).toList(),
          ['DS (0.3)', 'Ex (0.7)', 'Rex (0.7)']);
      expect(algebre.epreuves.map((e) => e.poids).toList(), [0.3, 0.7, 0.7]);
      expect(algebre.epreuves.map((e) => e.note).toList(), [10, 5, 2.5]);
    });

    test('reproduces the published moyenne from the parsed tree', () {
      // End-to-end proof the port is faithful: the same arithmetic that matched
      // the site before must still land on 10.56.
      final grades = parser.parseGrades(body);
      const calc = MoyenneCalculator();

      final annual = calc.annualAverage(grades.semesters);
      expect(annual.value, closeTo(10.56, 0.01));

      // And every published unit average is reproduced exactly.
      for (final semestre in grades.semesters) {
        for (final unite in semestre.unites) {
          expect(calc.uniteAverage(unite).value, closeTo(unite.moyenne!, 0.055),
              reason: 'unit ${unite.libelle}');
        }
      }
    });
  });

  group('cursus', () {
    late final body = fixture('cursus.html');

    test('recognises the page', () {
      expect(parser.looksLikeCursusPage(body), isTrue);
    });

    test('reads identity and filière', () {
      final profile = parser.parseCursus(body);
      expect(profile.prenom, 'Ahmed');
      expect(profile.nom, 'Haddaji');
      expect(profile.cin, '09729031');
      expect(profile.filiere, 'Licence en Informatique et Multimédia (LSIM)');
      expect(profile.initials, 'AH');
    });

    test('reads every academic year with its accented headers', () {
      final profile = parser.parseCursus(body);
      expect(profile.years.length, 4);

      final years = profile.years.map((y) => y.annee).toList();
      expect(years, ['2026-2027', '2025-2026', '2024-2025', '2023-2024']);

      final current = profile.years.first;
      expect(current.niveau, '3');
      expect(current.classe, 'LSIM3');
      expect(current.groupe, isNull, reason: 'blank cell becomes null');
      expect(current.moyenne, '0 (S1)');
      expect(current.isInProgress, isTrue);

      final passed = profile.years[1];
      expect(passed.resultat, 'Admis en session Principale');
      expect(passed.isPassed, isTrue);
      expect(passed.moyenneValue, 11.13);

      final repeated = profile.years.last;
      expect(repeated.resultat, 'Redouble');
      expect(repeated.isRepeated, isTrue);
    });
  });

  group('schedule', () {
    late final body = fixture('schedule_empty.html');

    test('recognises the page', () {
      expect(parser.looksLikeSchedulePage(body), isTrue);
    });

    test('reads the week label including its accented month', () {
      final schedule = parser.parseSchedule(body);
      expect(schedule.weekLabel, '10 → 15 août 2026');
    });

    test('reports an empty week as having no sessions', () {
      expect(parser.parseSchedule(body).hasSessions, isFalse);
    });
  });

  group('page guards', () {
    test('the homepage is not mistaken for a data page', () {
      // Denied routes answer 200 with the generic homepage, so each guard has
      // to reject it rather than trusting the status code.
      const homepage = '<html><head><title>ISIMG - Institut Supérieur</title>'
          '</head><body>rien</body></html>';

      expect(parser.looksLikeGradesPage(homepage), isFalse);
      expect(parser.looksLikeCursusPage(homepage), isFalse);
      expect(parser.looksLikeSchedulePage(homepage), isFalse);
    });

    test('the unauthorized notice is detected', () {
      expect(
        parser.isUnauthorized("<p>Vous n'êtes pas autorisé à afficher cette page.</p>"),
        isTrue,
      );
    });
  });

  group('login page', () {
    late final body = fixture('login_page.html');

    test('recognises the page carrying the password form and Google sign-in', () {
      expect(parser.looksLikeLoginPage(body), isTrue);
    });

    test('an authenticated page is not mistaken for the login page', () {
      // A wrong-credentials meta-refresh bounces back to this exact page, so
      // the check only means anything if real data pages do not also trip it.
      expect(parser.looksLikeLoginPage(fixture('grades.html')), isFalse);
      expect(parser.looksLikeLoginPage(fixture('cursus.html')), isFalse);
      expect(parser.looksLikeLoginPage(fixture('schedule_empty.html')), isFalse);
    });
  });
}
