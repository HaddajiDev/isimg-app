import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/models/absences.dart';
import 'package:isimg_app/models/exam.dart';
import 'package:isimg_app/models/calendar.dart';
import 'package:isimg_app/models/news.dart';
import 'package:isimg_app/models/notifications.dart';
import 'package:isimg_app/models/stage.dart';
import 'package:isimg_app/models/student.dart';
import 'package:isimg_app/core/api_exception.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/screens/login_screen.dart';
import 'package:isimg_app/theme/app_theme.dart';

class _ExpiredPasswordApi implements ApiClient {
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

  var loginCalls = 0;

  @override
  Future<LoginResult> login(String username, String password) async {
    loginCalls++;
    throw ApiException('password_expired', statusCode: 403);
  }

  @override
  Future<void> verifyOtp({
    required String session,
    required String token2fa,
    required String code,
  }) async {}

  @override
  Future<Grades> getGrades({String? au, String? ss}) async =>
      Grades.fromJson({'semesters': <dynamic>[]});

  @override
  Future<Profile> getProfile() async => Profile.fromJson({'years': <dynamic>[]});

  @override
  Future<Schedule> getSchedule({String? week}) async =>
      Schedule.fromJson({'hasSessions': false});
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    PackageInfo.setMockInitialValues(
      appName: 'ISIMG',
      packageName: 'io.github.haddajidev.isimg',
      version: '1.0.10',
      buildNumber: '11',
      buildSignature: '',
    );
  });

  testWidgets('the login screen explains an expired password instead of blaming it',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _ExpiredPasswordApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: buildAppTheme(), home: const LoginScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField).first, '2024666');
    await tester.enterText(find.byType(TextField).last, 'right-but-expired');
    await tester.tap(find.text('Se connecter'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.loginCalls, 1);

    expect(
      find.textContaining('mot de passe ISIMG a expiré'),
      findsOneWidget,
    );
    expect(find.textContaining('isimg.rnu.tn'), findsOneWidget);
    expect(find.text('Identifiants incorrects'), findsNothing);
  });
}
