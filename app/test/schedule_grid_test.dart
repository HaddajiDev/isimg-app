import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isimg_app/core/demo_data.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/models/seance.dart';
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
      // Monday 21 October 2024, matching the timetable this was modelled on.
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

  test('the demo week covers every day and slot of the timetable', () {
    final schedule = demoSchedule(week: '2024-10-21');

    expect(schedule.hasSessions, isTrue);
    expect(schedule.sessions, hasLength(22));
    // Monday through Saturday all have at least one class.
    for (var day = 1; day <= 6; day++) {
      expect(
        schedule.sessions.where((s) => s.weekday == day),
        isNotEmpty,
        reason: 'weekday $day should have classes',
      );
    }
    // All three kinds are present, so the grid's colour coding is exercised.
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
