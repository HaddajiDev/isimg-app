import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isimg_app/core/demo_data.dart';
import 'package:isimg_app/models/absences.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/models/seance.dart';
import 'package:isimg_app/providers/schedule_provider.dart' show mondayOf;
import 'package:isimg_app/theme/app_theme.dart';
import 'package:isimg_app/widgets/schedule_grid.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('lays out a day column per weekday with its date', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(ScheduleGrid(
      sessions: const [
        Seance(weekday: 1, slot: '08:15-09:45', type: SeanceType.cours, matiere: 'Algèbre 1'),
      ],

      weekStart: DateTime(2024, 10, 21),
    )));

    expect(find.text('Séance'), findsOneWidget);
    for (final day in ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi']) {
      expect(find.text(day), findsOneWidget);
    }
    expect(find.text('21/10'), findsOneWidget);
    expect(find.text('26/10'), findsOneWidget);
  });

  testWidgets('renders a class with its teacher and room', (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(ScheduleGrid(
      sessions: const [
        Seance(
          weekday: 2,
          slot: '08:15-09:45',
          type: SeanceType.td,
          matiere: 'Techniques de communication 1',
          enseignant: 'Imen Jemai',
          salle: 'S08',
        ),
      ],
      weekStart: DateTime(2024, 10, 21),
    )));

    expect(find.text('TD'), findsOneWidget);
    expect(find.text('Techniques de communication 1'), findsOneWidget);
    expect(find.text('Imen Jemai'), findsOneWidget);
    expect(find.text('S08'), findsOneWidget);
  });

  testWidgets('shows both classes when the school books two into one cell',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(ScheduleGrid(
      sessions: const [
        Seance(weekday: 1, slot: '08:15-09:45', type: SeanceType.cours, matiere: 'Premier'),
        Seance(weekday: 1, slot: '08:15-09:45', type: SeanceType.tp, matiere: 'Second'),
      ],
      weekStart: DateTime(2024, 10, 21),
    )));

    expect(find.text('Premier'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks a make-up session so it is not read as a normal class',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(ScheduleGrid(
      sessions: const [
        Seance(
          weekday: 1,
          slot: '08:15-09:45',
          type: SeanceType.tp,
          matiere: 'Architecture web',
          rattrapage: true,
        ),
        Seance(weekday: 2, slot: '08:15-09:45', type: SeanceType.tp, matiere: 'Infographie'),
      ],
      weekStart: DateTime(2024, 10, 21),
    )));

    expect(find.text('RATTRAPAGE'), findsOneWidget);
  });

  testWidgets('orders slot rows by start time regardless of input order',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(ScheduleGrid(
      sessions: const [
        Seance(weekday: 1, slot: '16:15-17:45', type: SeanceType.tp, matiere: 'Tard'),
        Seance(weekday: 1, slot: '08:15-09:45', type: SeanceType.cours, matiere: 'Tôt'),
      ],
      weekStart: DateTime(2024, 10, 21),
    )));

    final early = tester.getTopLeft(find.text('Tôt')).dy;
    final late = tester.getTopLeft(find.text('Tard')).dy;
    expect(early, lessThan(late));
  });

  testWidgets('highlights today\'s column and the current time\'s row on the current week',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final weekStart = mondayOf(DateTime.now());
    final today = DateTime.now().weekday;

    await tester.pumpWidget(wrap(ScheduleGrid(
      sessions: [
        Seance(weekday: today, slot: '00:00-23:59', type: SeanceType.cours, matiere: 'Maintenant'),
      ],
      weekStart: weekStart,
    )));

    final names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final todayLabel = tester.widget<Text>(find.text(names[today - 1]));
    expect(todayLabel.style?.color, AppColors.purple);

    final slotStart = tester.widget<Text>(find.text('00:00'));
    expect(slotStart.style?.color, AppColors.purple);
    expect(slotStart.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('does not highlight anything on a week that is not the current one',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final weekStart = mondayOf(DateTime.now()).add(const Duration(days: 70));
    final today = DateTime.now().weekday;

    await tester.pumpWidget(wrap(ScheduleGrid(
      sessions: [
        Seance(weekday: today, slot: '00:00-23:59', type: SeanceType.cours, matiere: 'Pas maintenant'),
      ],
      weekStart: weekStart,
    )));

    final names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final dayLabel = tester.widget<Text>(find.text(names[today - 1]));
    expect(dayLabel.style?.color, AppPalette.dark.textPrimary);

    final slotStart = tester.widget<Text>(find.text('00:00'));
    expect(slotStart.style?.color, AppPalette.dark.textSecondary);
  });

  testWidgets('flags a class the student was absent from with an ABSENT badge',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final weekStart = DateTime(2024, 10, 21); // Monday
    // Absence on Tuesday (weekStart + 1), séance index 1.
    final absentKey = Absences.slotKey(weekStart.add(const Duration(days: 1)), 1);

    await tester.pumpWidget(wrap(ScheduleGrid(
      sessions: const [
        Seance(weekday: 2, slot: '08:15-09:45', seanceIndex: 1, type: SeanceType.cours, matiere: 'Réseaux'),
        Seance(weekday: 3, slot: '08:15-09:45', seanceIndex: 1, type: SeanceType.tp, matiere: 'Base de données'),
      ],
      weekStart: weekStart,
      absentKeys: {absentKey},
    )));

    expect(find.text('ABSENT'), findsOneWidget);
    expect(find.text('Réseaux'), findsOneWidget);
    expect(find.text('Base de données'), findsOneWidget);
  });

  test('absentSlots keys each recorded absence by date and séance', () {
    final absences = Absences(
      s1: const SemestreAbsences(
        semestre: 1,
        entries: [
          AbsenceEntry(date: '2026-09-14', seance: '2', module: 'Maths'),
          AbsenceEntry(date: '15/09/2026', seance: '4', module: 'Réseaux'),
          AbsenceEntry(date: '', seance: '', module: 'ignored'),
        ],
      ),
    );

    expect(absences.absentSlots, contains(Absences.slotKey(DateTime(2026, 9, 14), 2)));
    expect(absences.absentSlots, contains(Absences.slotKey(DateTime(2026, 9, 15), 4)));
    expect(absences.absentSlots, hasLength(2));
  });

  test('the demo week covers every day and slot of the timetable', () {
    final schedule = demoSchedule(week: '2024-10-21');

    expect(schedule.hasSessions, isTrue);
    expect(schedule.sessions, hasLength(22));

    for (var day = 1; day <= 6; day++) {
      expect(
        schedule.sessions.where((s) => s.weekday == day),
        isNotEmpty,
        reason: 'weekday $day should have classes',
      );
    }

    for (final type in [SeanceType.cours, SeanceType.td, SeanceType.tp]) {
      expect(schedule.sessions.where((s) => s.type == type), isNotEmpty);
    }
  });

  test('the demo week label follows the requested Monday', () {
    expect(
      demoSchedule(week: '2024-10-21').weekLabel,
      'Semaine du 21/10/2024 au 26/10/2024',
    );
  });

  test('a schedule with sessions survives the offline cache round-trip', () {
    final original = demoSchedule(week: '2024-10-21');
    final restored = Schedule.fromJson(original.toJson());

    expect(restored.sessions, hasLength(original.sessions.length));
    final first = restored.sessions.first;
    expect(first.matiere, original.sessions.first.matiere);
    expect(first.type, original.sessions.first.type);
    expect(first.salle, original.sessions.first.salle);
    expect(first.weekday, original.sessions.first.weekday);
  });
}
