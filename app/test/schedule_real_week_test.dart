import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isimg_app/isimg/isimg_parser.dart';
import 'package:isimg_app/theme/app_theme.dart';
import 'package:isimg_app/widgets/schedule_grid.dart';

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

          weekStart: DateTime(2026, 4, 6),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);

    expect(find.text('Infographie'), findsWidgets);
    expect(find.text('Lab11'), findsOneWidget);

    for (final start in ['08:15', '09:55', '11:30', '14:00', '15:45']) {
      expect(find.text(start), findsOneWidget);
    }

    expect(find.text('RATTRAPAGE'), findsNWidgets(4));
  });
}
