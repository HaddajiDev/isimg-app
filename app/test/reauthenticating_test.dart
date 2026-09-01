import 'dart:async';

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
import 'package:isimg_app/core/credential_store.dart';
import 'package:isimg_app/core/grades_cache.dart';
import 'package:isimg_app/main.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/providers/grades_provider.dart';

class _RememberingCredentialStore extends CredentialStore {
  @override
  Future<Credentials?> read() async =>
      const Credentials(username: '2024666', password: 'pw');

  @override
  Future<void> save(Credentials credentials) async {}

  @override
  Future<void> clear() async {}
}

class _ControllableApi implements ApiClient {
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

  final _loginCompleter = Completer<LoginResult>();
  int gradesCalls = 0;

  void completeLogin() => _loginCompleter.complete(LoginOk());

  @override
  Future<LoginResult> login(String username, String password) => _loginCompleter.future;

  @override
  Future<void> verifyOtp({
    required String session,
    required String token2fa,
    required String code,
  }) async {}

  @override
  Future<Grades> getGrades({String? au, String? ss}) async {
    gradesCalls++;
    return Grades.fromJson({'nom': 'relevé live', 'semesters': <dynamic>[]});
  }

  @override
  Future<Profile> getProfile() async => Profile.fromJson({'years': <dynamic>[]});

  @override
  Future<Schedule> getSchedule({String? week}) async => Schedule(hasSessions: false);
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    SharedPreferences.setMockInitialValues({});
  });

  test('startup sits in reauthenticating, not submitting, while a remembered login is in flight',
      () async {
    final api = _ControllableApi();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        credentialStoreProvider.overrideWithValue(_RememberingCredentialStore()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authProvider).status, AuthStatus.reauthenticating);

    api.completeLogin();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authProvider).status, AuthStatus.authenticated);
  });

  test('a cached relevé shows during reauthenticating instead of erroring', () async {
    await GradesCache().save(
      '_default',
      '_default',
      Grades.fromJson({'nom': 'relevé en cache', 'semesters': <dynamic>[]}),
    );

    final api = _ControllableApi();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        credentialStoreProvider.overrideWithValue(_RememberingCredentialStore()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authProvider).status, AuthStatus.reauthenticating);

    final grades = await container.read(gradesProvider.future);
    expect(grades.nom, 'relevé en cache');
    expect(api.gradesCalls, 0, reason: 'no session exists yet to fetch with');

    api.completeLogin();
  });

  test('with nothing cached, the fetch waits for reauthentication instead of throwing no_session',
      () async {
    final api = _ControllableApi();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        credentialStoreProvider.overrideWithValue(_RememberingCredentialStore()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authProvider).status, AuthStatus.reauthenticating);

    var settled = false;
    unawaited(container.read(gradesProvider.future).then((_) => settled = true));

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(settled, isFalse);

    api.completeLogin();
    await Future<void>.delayed(Duration.zero);
    final grades = await container.read(gradesProvider.future);
    expect(grades.nom, 'relevé live');
    expect(api.gradesCalls, 1);
  });

  testWidgets('the shell renders during reauthenticating instead of a blocking spinner',
      (tester) async {
    final api = _ControllableApi();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        credentialStoreProvider.overrideWithValue(_RememberingCredentialStore()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IsimgApp()),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(container.read(authProvider).status, AuthStatus.reauthenticating);

    expect(find.text('Se connecter'), findsNothing);

    expect(find.text('Votre semaine'), findsOneWidget);

    api.completeLogin();
    await tester.pump();
  });
}
