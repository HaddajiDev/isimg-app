import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:isimg_app/core/api_exception.dart';
import 'package:isimg_app/core/profile_cache.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/providers/profile_provider.dart';

Profile _profile(String name) => Profile.fromJson({'prenom': name, 'years': <dynamic>[]});

class FlakyApi implements ApiClient {
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

  ApiException? failWith;
  int profileCalls = 0;
  String name = 'profil en ligne';

  @override
  Future<Profile> getProfile() async {
    profileCalls++;
    final failure = failWith;
    if (failure != null) throw failure;
    return _profile(name);
  }

  @override
  Future<Grades> getGrades({String? au, String? ss}) async =>
      Grades.fromJson({'semesters': <dynamic>[]});

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

ProviderContainer makeContainer(FlakyApi api) {
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith(() => _AuthedNotifier()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('store', () {
    test('a saved profile comes back with its capture time', () async {
      final cache = ProfileCache();
      await cache.save(_profile('Ahmed'));

      final cached = await cache.read();
      expect(cached, isNotNull);
      expect(cached!.profile.prenom, 'Ahmed');
      expect(DateTime.now().difference(cached.capturedAt).inSeconds, lessThan(5));
    });

    test('an empty cache is a miss', () async {
      expect(await ProfileCache().read(), isNull);
    });

    test('a corrupt entry behaves as a miss rather than throwing', () async {
      SharedPreferences.setMockInitialValues({'profile_v1': 'not json'});
      expect(await ProfileCache().read(), isNull);
    });

    test('a saved profile is replaced, not appended, on the next save', () async {
      final cache = ProfileCache();
      await cache.save(_profile('Ahmed'));
      await cache.save(_profile('Sami'));

      expect((await cache.read())!.profile.prenom, 'Sami');
    });
  });

  group('offline fallback', () {
    test('a live fetch is stored and reported as live', () async {
      final api = FlakyApi();
      final container = makeContainer(api);

      final profile = await container.read(profileProvider.future);
      expect(profile.prenom, 'profil en ligne');

      expect(await ProfileCache().read(), isNotNull);
    });

    test('losing the connection serves the saved profile', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(profileProvider.future);

      api.failWith = ApiException('network_error');
      container.invalidate(profileProvider);

      final profile = await container.read(profileProvider.future);
      expect(profile.prenom, 'profil en ligne');
    });

    test('a timeout also falls back', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(profileProvider.future);

      api.failWith = ApiException('upstream_timeout');
      container.invalidate(profileProvider);

      expect((await container.read(profileProvider.future)).prenom, 'profil en ligne');
    });

    test('offline with nothing saved still reports the failure', () async {
      final api = FlakyApi()..failWith = ApiException('network_error');
      final container = makeContainer(api);

      await expectLater(
        container.read(profileProvider.future),
        throwsA(isA<ApiException>()),
      );
    });

    test('an expired session is never masked by the cache', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(profileProvider.future);

      api.failWith = ApiException('session_expired', statusCode: 401);
      container.invalidate(profileProvider);

      await expectLater(
        container.read(profileProvider.future),
        throwsA(isA<ApiException>().having((e) => e.isSessionExpired, 'expired', isTrue)),
      );
    });

    test('a later live fetch replaces the stored copy', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(profileProvider.future);

      api.name = 'profil mis à jour';
      container.invalidate(profileProvider);
      await container.read(profileProvider.future);

      api.failWith = ApiException('network_error');
      container.invalidate(profileProvider);

      final profile = await container.read(profileProvider.future);
      expect(profile.prenom, 'profil mis à jour');
    });
  });
}
