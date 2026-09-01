import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/models/absences.dart';
import 'package:isimg_app/models/exam.dart';
import 'package:isimg_app/models/calendar.dart';
import 'package:isimg_app/models/news.dart';
import 'package:isimg_app/models/notifications.dart';
import 'package:isimg_app/models/stage.dart';
import 'package:isimg_app/models/student.dart';
import 'package:isimg_app/core/api_exception.dart';
import 'package:isimg_app/core/credential_store.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';

class FakeCredentialStore extends CredentialStore {
  Credentials? stored;
  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<Credentials?> read() async => stored;

  @override
  Future<bool> hasCredentials() async => stored != null;

  @override
  Future<void> save(Credentials credentials) async {
    stored = credentials;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    stored = null;
    clearCount++;
  }
}

class ScriptedApi implements ApiClient {
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

  final List<Object> outcomes;
  final List<(String, String)> attempts = [];

  ScriptedApi(this.outcomes);

  @override
  Future<LoginResult> login(String username, String password) async {
    attempts.add((username, password));
    final next = outcomes.isEmpty ? Exception('no more outcomes') : outcomes.removeAt(0);
    if (next is LoginResult) return next;
    throw next;
  }

  @override
  Future<void> verifyOtp({required String session, required String token2fa, required String code}) async {}

  @override
  Future<Grades> getGrades({String? au, String? ss}) async =>
      Grades.fromJson({'semesters': <dynamic>[]});

  @override
  Future<Profile> getProfile() async =>
      Profile.fromJson({'years': <dynamic>[]});

  @override
  Future<Schedule> getSchedule({String? week}) async =>
      Schedule.fromJson({'hasSessions': false});
}

ProviderContainer makeContainer(ScriptedApi api, FakeCredentialStore store) {
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      credentialStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<AuthState> settle(ProviderContainer container) async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(Duration.zero);
    final state = container.read(authProvider);
    if (state.status != AuthStatus.checking && state.status != AuthStatus.submitting) {
      return state;
    }
  }
  return container.read(authProvider);
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
  });

  test('credentials are saved only when "remember me" is ticked', () async {
    final store = FakeCredentialStore();
    final container = makeContainer(ScriptedApi([LoginOk()]), store);
    await settle(container);

    await container.read(authProvider.notifier).login('2024666', 'pw', rememberMe: false);

    expect(store.stored, isNull);
    expect(store.saveCount, 0);
  });

  test('ticking "remember me" stores them after a successful login', () async {
    final store = FakeCredentialStore();
    final container = makeContainer(ScriptedApi([LoginOk()]), store);
    await settle(container);

    await container.read(authProvider.notifier).login('2024666', 'pw', rememberMe: true);

    expect(store.stored?.username, '2024666');
    expect(store.stored?.password, 'pw');
  });

  test('a rejected login stores nothing', () async {
    final store = FakeCredentialStore();
    final container = makeContainer(ScriptedApi([Exception('bad creds')]), store);
    await settle(container);

    await container.read(authProvider.notifier).login('2024666', 'wrong', rememberMe: true);

    expect(store.stored, isNull);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });

  test('credentials are withheld until an OTP login actually completes', () async {
    final store = FakeCredentialStore();
    final api = ScriptedApi([LoginOtpRequired(session: 'sess', token2fa: 'tok')]);
    final container = makeContainer(api, store);
    await settle(container);

    await container.read(authProvider.notifier).login('2024666', 'pw', rememberMe: true);
    expect(container.read(authProvider).status, AuthStatus.otpPending);

    expect(store.stored, isNull);

    await container.read(authProvider.notifier).verifyOtp('123456');
    expect(container.read(authProvider).status, AuthStatus.authenticated);
    expect(store.stored?.password, 'pw');
  });

  test('a stored login signs the student in at startup', () async {
    final store = FakeCredentialStore()
      ..stored = const Credentials(username: '2024666', password: 'pw');
    final api = ScriptedApi([LoginOk()]);
    final container = makeContainer(api, store);

    final state = await settle(container);

    expect(state.status, AuthStatus.authenticated);

    expect(api.attempts, [('2024666', 'pw')]);
  });

  test('startup falls back to the login screen when nothing is stored', () async {
    final container = makeContainer(ScriptedApi([]), FakeCredentialStore());
    expect((await settle(container)).status, AuthStatus.unauthenticated);
  });

  test('an expired session is renewed silently', () async {
    final store = FakeCredentialStore()
      ..stored = const Credentials(username: '2024666', password: 'pw');

    final api = ScriptedApi([LoginOk(), LoginOk()]);
    final container = makeContainer(api, store);
    await settle(container);
    final before = container.read(authProvider).sessionGeneration;

    await container.read(authProvider.notifier).handleSessionExpired();

    final state = container.read(authProvider);
    expect(state.status, AuthStatus.authenticated);

    expect(api.attempts.length, 2);
    expect(state.sessionGeneration, greaterThan(before));

    expect(store.stored, isNotNull);
  });

  test('expiry falls back to the login screen when the password no longer works',
      () async {
    final store = FakeCredentialStore()
      ..stored = const Credentials(username: '2024666', password: 'old-pw');
    final api = ScriptedApi([LoginOk(), Exception('password changed')]);
    final container = makeContainer(api, store);
    await settle(container);

    await container.read(authProvider.notifier).handleSessionExpired();

    expect(container.read(authProvider).status, AuthStatus.unauthenticated);

    expect(store.stored, isNull);
  });

  test('expiry surfaces "wrong credentials" when the site explicitly rejects them',
      () async {
    final store = FakeCredentialStore()
      ..stored = const Credentials(username: '2024666', password: 'old-pw');
    final api = ScriptedApi([
      LoginOk(),
      ApiException('invalid_credentials', statusCode: 401),
    ]);
    final container = makeContainer(api, store);
    await settle(container);

    await container.read(authProvider.notifier).handleSessionExpired();

    final state = container.read(authProvider);
    expect(state.status, AuthStatus.unauthenticated);
    expect(state.errorMessage, 'Identifiants incorrects');
    expect(store.stored, isNull);
  });

  test('expiry stays silent when renewal fails for a reason unrelated to the password',
      () async {
    final store = FakeCredentialStore()
      ..stored = const Credentials(username: '2024666', password: 'pw');
    final api = ScriptedApi([
      LoginOk(),
      ApiException('network_error'),
    ]);
    final container = makeContainer(api, store);
    await settle(container);

    await container.read(authProvider.notifier).handleSessionExpired();

    final state = container.read(authProvider);
    expect(state.status, AuthStatus.unauthenticated);
    expect(state.errorMessage, isNull);
  });

  test('a startup silent login rejected by the site reports "wrong credentials"',
      () async {
    final store = FakeCredentialStore()
      ..stored = const Credentials(username: '2024666', password: 'wrong');
    final api = ScriptedApi([ApiException('invalid_credentials', statusCode: 401)]);
    final container = makeContainer(api, store);

    final state = await settle(container);

    expect(state.status, AuthStatus.unauthenticated);
    expect(state.errorMessage, 'Identifiants incorrects');
    expect(store.stored, isNull);
  });

  group('an expired ISIMG password', () {
    const expired = 'Votre mot de passe ISIMG a expiré. Changez-le sur '
        'isimg.rnu.tn, puis reconnectez-vous.';

    test('is explained rather than blamed on the credentials', () async {
      final store = FakeCredentialStore();
      final api = ScriptedApi([ApiException('password_expired', statusCode: 403)]);
      final container = makeContainer(api, store);
      await settle(container);

      await container
          .read(authProvider.notifier)
          .login('2024666', 'right-but-expired', rememberMe: true);

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);

      expect(state.errorMessage, expired);

      expect(store.stored, isNull);
    });

    test('is explained when it surfaces during a silent startup login', () async {
      final store = FakeCredentialStore()
        ..stored = const Credentials(username: '2024666', password: 'pw');
      final api = ScriptedApi([ApiException('password_expired', statusCode: 403)]);
      final container = makeContainer(api, store);

      final state = await settle(container);

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, expired);

      expect(store.stored, isNull);
    });

    test('is explained when it surfaces while renewing a lapsed session', () async {
      final store = FakeCredentialStore()
        ..stored = const Credentials(username: '2024666', password: 'pw');
      final api = ScriptedApi([LoginOk(), ApiException('password_expired', statusCode: 403)]);
      final container = makeContainer(api, store);
      await settle(container);

      await container.read(authProvider.notifier).handleSessionExpired();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, expired);
    });
  });

  test('expiry cannot be recovered unattended when a new OTP is demanded', () async {
    final store = FakeCredentialStore()
      ..stored = const Credentials(username: '2024666', password: 'pw');
    final api = ScriptedApi([LoginOk(), LoginOtpRequired(session: 'sess', token2fa: 'tok')]);
    final container = makeContainer(api, store);
    await settle(container);

    await container.read(authProvider.notifier).handleSessionExpired();

    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });

  test('signing out forgets the stored login', () async {
    final store = FakeCredentialStore()
      ..stored = const Credentials(username: '2024666', password: 'pw');
    final container = makeContainer(ScriptedApi([LoginOk()]), store);
    await settle(container);

    await container.read(authProvider.notifier).logout();

    expect(store.stored, isNull);
    expect(store.clearCount, greaterThan(0));
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });
}
