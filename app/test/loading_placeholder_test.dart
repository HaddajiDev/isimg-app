import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/models/absences.dart';
import 'package:isimg_app/models/exam.dart';
import 'package:isimg_app/models/calendar.dart';
import 'package:isimg_app/models/news.dart';
import 'package:isimg_app/models/notifications.dart';
import 'package:isimg_app/models/stage.dart';
import 'package:isimg_app/models/student.dart';
import 'package:isimg_app/core/grades_cache.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/screens/grades_screen.dart';
import 'package:isimg_app/theme/app_theme.dart';
import 'package:isimg_app/widgets/student_avatar.dart';

class _StuckApi implements ApiClient {
  @override
  Future<StudentInfo> getStudentDetails() => throw UnimplementedError();

  @override
  Future<NewsFeed> getNews() => throw UnimplementedError();

  @override
  Future<NotifData> getNotifications() => throw UnimplementedError();

  @override
  Future<Stages> getStages() => throw UnimplementedError();

  @override
  Future<UniversityCalendar> getUniversityCalendar() => throw UnimplementedError();

  @override
  Future<Absences> getAbsences() => throw UnimplementedError();

  @override
  Future<ExamsSchedule> getUpcomingExams() => throw UnimplementedError();

  @override
  Future<Grades> getGrades({String? au, String? ss}) => Completer<Grades>().future;

  @override
  Future<Profile> getProfile() async => Profile.fromJson({'years': <dynamic>[]});

  @override
  Future<Schedule> getSchedule({String? week}) async => Schedule(hasSessions: false);

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

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    SharedPreferences.setMockInitialValues({});
    StudentAvatar.debugDisableRemote = true;
  });

  tearDown(() => StudentAvatar.debugDisableRemote = false);

  testWidgets(
    'a cached relevé shows immediately while the live fetch is still stuck loading',
    (tester) async {
      await GradesCache().save(
        '_default',
        '_default',
        Grades.fromJson({'nom': 'Étudiant Cache', 'semesters': <dynamic>[]}),
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(_StuckApi()),
          authProvider.overrideWith(() => _AuthedNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(body: GradesScreen()),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Étudiant Cache'), findsOneWidget);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'falls back to the skeleton when there is nothing cached to seed with',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(_StuckApi()),
          authProvider.overrideWith(() => _AuthedNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(body: GradesScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Étudiant Cache'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
}
