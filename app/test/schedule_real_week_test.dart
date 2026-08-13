import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isimg_app/isimg/isimg_parser.dart';
import 'package:isimg_app/theme/app_theme.dart';
import 'package:isimg_app/widgets/schedule_grid.dart';

/// End-to-end: the captured week goes through the parser and out to the grid,
/// so a markup change cannot quietly stop at "parsed but never displayed".
void main() {
  testWidgets('a real captured week lays out in the grid', (tester) async {
    tester.view.physicalSize = const Size(2400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final body = File('test/fixtures/schedule_populated.html').readAsStringSync();
    final schedule = const IsimgParser().parseSchedule(body);

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: ScheduleGrid(
          sessions: schedule.sessions,
          // Monday of the captured week, 6 April 2026.
          weekStart: DateTime(2026, 4, 6),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    // A class the student would actually look for, with its room.
    expect(find.text('Infographie'), findsWidgets);
    expect(find.text('Lab11'), findsOneWidget);
    // Every slot row the week uses is present.
    for (final start in ['08:15', '09:55', '11:30', '14:00', '15:45']) {
      expect(find.text(start), findsOneWidget);
    }
    // The make-up sessions are all marked.
    expect(find.text('RATTRAPAGE'), findsNWidgets(4));
  });
}
