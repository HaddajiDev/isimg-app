import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/core/moyenne_calculator.dart';
import 'package:isimg_app/isimg/isimg_parser.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/models/seance.dart';

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

  group('schedule (empty week)', () {
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
      expect(parser.parseSchedule(body).sessions, isEmpty);
    });
  });

  group('schedule (populated week)', () {
    late final body = fixture('schedule_populated.html');
    late final schedule = parser.parseSchedule(body);

    test('a full week is not mistaken for a free one', () {
      // The mobile view carries a permanently-hidden "Aucune séance" block that
      // JS reveals per day. Searching the whole body for it reported every week
      // as free, so this full week rendered as "no classes".
      expect(body, contains('Aucune séance'));
      expect(schedule.hasSessions, isTrue);
    });

    test('reads the week label', () {
      expect(schedule.weekLabel, '06 → 11 avril 2026');
    });

    test('reads every class in the grid', () {
      expect(schedule.sessions, hasLength(22));
    });

    test('places a class on the right day and slot', () {
      final first = schedule.sessions.first;
      expect(first.weekday, 1);
      expect(first.slot, '08:15-09:45');
      expect(first.matiere, 'Numérisation et codage des objets multimedia');
      expect(first.type, SeanceType.cours);
      expect(first.salle, 'A5');
      expect(first.enseignant, 'Chaima Bouhlila');
      expect(first.rattrapage, isFalse);
    });

    test('tells room and teacher apart by their icons, not their order', () {
      // Both are plain truncating spans; only the icon distinguishes them.
      for (final seance in schedule.sessions) {
        expect(seance.salle, isNot(contains(' ')),
            reason: 'a room is a code like A5 or Lab11, never a person');
        expect(seance.enseignant, contains(' '),
            reason: 'every teacher in this capture has a first and last name');
      }
    });

    test('reads all three kinds of class from their badges', () {
      final byType = <SeanceType, int>{};
      for (final seance in schedule.sessions) {
        byType[seance.type] = (byType[seance.type] ?? 0) + 1;
      }
      expect(byType[SeanceType.cours], 13);
      expect(byType[SeanceType.tp], 8);
      expect(byType[SeanceType.td], 1);
      expect(byType[SeanceType.autre], isNull);
    });

    test('flags make-up sessions', () {
      final rattrapages = schedule.sessions.where((s) => s.rattrapage).toList();
      expect(rattrapages, hasLength(4));
      expect(
        rattrapages.map((s) => (s.weekday, s.slot, s.matiere)),
        [
          (2, '08:15-09:45', 'Développement d\'applications mobiles'),
          (1, '11:30-13:00', 'Numérisation et codage des objets multimedia'),
          (6, '11:30-13:00', 'Infographie'),
          (5, '14:00-15:30', 'Architecture web'),
        ],
      );
    });

    test('normalises the arrow-separated slot into the app\'s shape', () {
      // The site prints "08:15 → 09:45"; ordering and slot matching both need
      // the hyphen form.
      expect(body, contains('08:15 → 09:45'));
      final slots = {for (final s in schedule.sessions) s.slot};
      expect(slots, {
        '08:15-09:45',
        '09:55-11:25',
        '11:30-13:00',
        '14:00-15:30',
        '15:45-17:15',
      });
      expect(schedule.sessions.first.startMinutes, 8 * 60 + 15);
    });

    test('covers Monday through Saturday', () {
      final days = schedule.sessions.map((s) => s.weekday).toSet();
      expect(days, {1, 2, 3, 4, 5, 6});
    });

    test('survives markup truncated mid-row instead of throwing', () {
      // A short read or a changed grid must degrade, not crash: the loop reads
      // a whole row per step.
      final cut = body.substring(0, body.indexOf('11:30 → 13:00'));
      final partial = parser.parseSchedule(cut);
      expect(partial.sessions, isNotEmpty);
      expect(partial.sessions.every((s) => s.slot != '11:30-13:00'), isTrue);
    });

    test('keeps room and teacher apart when a class has no room', () {
      // Reading them by position instead of by icon put the teacher's name in
      // the room field as soon as one span was missing.
      final noRoom = body.replaceFirst(
        RegExp(r'<span class="truncate">\s*<i class="fa-solid fa-location-dot mr-1"></i>A5\s*</span>'),
        '',
      );
      expect(noRoom, isNot(body), reason: 'the room span should have been removed');

      final first = parser.parseSchedule(noRoom).sessions.first;
      expect(first.salle, isNull);
      expect(first.enseignant, 'Chaima Bouhlila');
    });

    test('a populated week survives the offline cache round-trip', () {
      final restored = Schedule.fromJson(schedule.toJson());
      expect(restored.sessions, hasLength(schedule.sessions.length));
      expect(restored.hasSessions, isTrue);
      final rattrapage = restored.sessions.firstWhere((s) => s.rattrapage);
      expect(rattrapage.matiere, 'Développement d\'applications mobiles');
    });
  });

  group('schedule grid shapes', () {
    /// A minimal grid of the same shape the site emits: a corner cell, one
    /// sticky header per day, then per row a slot label and one cell per day,
    /// with a single class in each row's first day.
    String syntheticGrid({required int days, required int rows, int dropTrailing = 0}) {
      const card = '<div class="group border-l-4">'
          '<div class="flex"><p class="text-sm font-semibold">Algèbre</p>'
          '<span class="font-bold">Cours</span></div>'
          '<div class="mt-1 flex">'
          '<span class="truncate"><i class="fa-solid fa-location-dot mr-1"></i>A1</span>'
          '<span class="truncate"><i class="fa-solid fa-user mr-1"></i>Jean Dupont</span>'
          '</div></div>';

      final cells = <String>[
        '<div class="sticky top-0 border-b border-r p-4"></div>',
        for (var d = 0; d < days; d++)
          '<div class="sticky top-0 border-b p-2"><p class="text-sm">J$d</p></div>',
      ];
      for (var r = 0; r < rows; r++) {
        cells.add('<div class="border-r border-b p-3">0${8 + r}:15 → 0${9 + r}:45</div>');
        for (var d = 0; d < days; d++) {
          cells.add('<div class="border-b p-2">${d == 0 ? card : ''}</div>');
        }
      }
      return '<html><body><section id="desktop-view">'
          '<div class="grid grid-cols-[80px_repeat($days,minmax(180px,1fr))]">'
          '${cells.take(cells.length - dropTrailing).join()}'
          '</div></section></body></html>';
    }

    test('a last row cut short does not throw', () {
      // A whole row is read per step, so a row ending exactly at the list's end
      // used to index one past it.
      final schedule = parser.parseSchedule(syntheticGrid(days: 6, rows: 5, dropTrailing: 1));
      expect(schedule.sessions, hasLength(4));
      expect(schedule.sessions.every((s) => s.weekday == 1), isTrue);
    });

    test('reads the day count off the header instead of assuming six', () {
      // Assuming six columns misaligns every following row when the count
      // differs — classes then land on the wrong days rather than going
      // missing, which is the harder kind of wrong to notice.
      for (final days in [5, 6, 7]) {
        final schedule = parser.parseSchedule(syntheticGrid(days: days, rows: 4));
        expect(schedule.sessions, hasLength(4), reason: '$days-day week');
        expect(schedule.sessions.map((s) => s.weekday).toSet(), {1},
            reason: '$days-day week keeps its classes on Monday');
        expect(schedule.sessions.first.slot, '08:15-09:45', reason: '$days-day week');
      }
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
