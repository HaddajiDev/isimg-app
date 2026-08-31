import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/models/absences.dart';
import 'package:isimg_app/models/exam.dart';
import 'package:isimg_app/isimg/isimg_parser.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/screens/schedule_screen.dart';
import 'package:isimg_app/theme/app_theme.dart';
import 'package:isimg_app/widgets/schedule_grid.dart';

class _FixedApi implements ApiClient {
  @override
  Future<Absences> getAbsences() => throw UnimplementedError();

  @override
  Future<ExamsSchedule> getUpcomingExams() => throw UnimplementedError();

  final Schedule schedule;

  _FixedApi(this.schedule);

  @override
  Future<Schedule> getSchedule({String? week}) async => schedule;

  @override
  Future<Grades> getGrades({String? au, String? ss}) async =>
      Grades.fromJson({'semesters': <dynamic>[]});

  @override
  Future<Profile> getProfile() async => Profile.fromJson({'years': <dynamic>[]});

  @override
  Future<LoginResult> login(String username, String password) async => LoginOk();

  @override
  Future<void> verifyOtp({
    required String session,
    required String token2fa,
    required String code,
  }) async {}
}

class _AuthedNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

Future<void> pumpSchedule(WidgetTester tester, Schedule schedule) async {
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(_FixedApi(schedule)),
      authProvider.overrideWith(() => _AuthedNotifier()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: ScheduleScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a genuinely free week says so', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSchedule(tester, Schedule(weekLabel: 'semaine', hasSessions: false));

    expect(find.text('Aucun cours cette semaine'), findsOneWidget);
    expect(find.byType(ScheduleGrid), findsNothing);
  });

  testWidgets('a week with classes lays out the grid, never the free-week notice',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final real = const IsimgParser()
        .parseSchedule(File('test/fixtures/schedule_populated.html').readAsStringSync());
    await pumpSchedule(tester, real);

    expect(find.byType(ScheduleGrid), findsOneWidget);
    expect(find.text('Aucun cours cette semaine'), findsNothing);

    expect(find.text('RATTRAPAGE'), findsNWidgets(4));
  });

  testWidgets('classes that could not be read are reported, not shown as a free week',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSchedule(tester, Schedule(weekLabel: 'semaine', hasSessions: true));

    expect(find.text('Aucun cours cette semaine'), findsNothing);
    expect(find.byType(ScheduleGrid), findsNothing);
    expect(find.text('Emploi illisible'), findsOneWidget);
  });
}
