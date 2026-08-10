import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/core/api_exception.dart';
import 'package:isimg_app/core/grades_cache.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/providers/grades_provider.dart';

Grades _grades(String label) => Grades.fromJson({
      'nom': label,
      'moyenneGenerale': '14.25',
      'semesters': <dynamic>[],
    });

/// Serves one relevé, then fails however the test asks.
class FlakyApi implements ApiClient {
  ApiException? failWith;
  int gradesCalls = 0;
  String label = 'relevé en ligne';

  @override
  Future<Grades> getGrades({String? au, String? ss}) async {
    gradesCalls++;
    final failure = failWith;
    if (failure != null) throw failure;
    return _grades(label);
  }

  @override
  Future<Schedule> getSchedule({String? week}) async => Schedule(hasSessions: false);

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
    test('a saved relevé comes back with its capture time', () async {
      final cache = GradesCache();
      await cache.save('2025/2026', '1', _grades('relevé'));

      final cached = await cache.read('2025/2026', '1');
      expect(cached, isNotNull);
      expect(cached!.grades.nom, 'relevé');
      expect(DateTime.now().difference(cached.capturedAt).inSeconds, lessThan(5));
    });

    test('année/session combinations are kept separately', () async {
      final cache = GradesCache();
      await cache.save('2025/2026', '1', _grades('A'));
      await cache.save('2024/2025', '1', _grades('B'));

      expect((await cache.read('2025/2026', '1'))!.grades.nom, 'A');
      expect((await cache.read('2024/2025', '1'))!.grades.nom, 'B');
    });

    test('an unknown combination is a miss', () async {
      expect(await GradesCache().read('1999', '1'), isNull);
    });

    test('a corrupt entry behaves as a miss rather than throwing', () async {
      SharedPreferences.setMockInitialValues({'grades_v1:2025/2026|1': 'not json'});
      expect(await GradesCache().read('2025/2026', '1'), isNull);
    });
  });

  group('offline fallback', () {
    test('a live fetch is stored and reported as live', () async {
      final api = FlakyApi();
      final container = makeContainer(api);

      final grades = await container.read(gradesProvider.future);
      expect(grades.nom, 'relevé en ligne');

      final cached = await GradesCache().read('_default', '_default');
      expect(cached, isNotNull);
    });

    test('losing the connection serves the saved relevé', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(gradesProvider.future);

      api.failWith = ApiException('network_error');
      container.invalidate(gradesProvider);

      final grades = await container.read(gradesProvider.future);
      expect(grades.nom, 'relevé en ligne');
    });

    test('a timeout also falls back', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(gradesProvider.future);

      api.failWith = ApiException('upstream_timeout');
      container.invalidate(gradesProvider);

      expect((await container.read(gradesProvider.future)).nom, 'relevé en ligne');
    });

    test('offline with nothing saved still reports the failure', () async {
      final api = FlakyApi()..failWith = ApiException('network_error');
      final container = makeContainer(api);

      await expectLater(
        container.read(gradesProvider.future),
        throwsA(isA<ApiException>()),
      );
    });

    test('an expired session is never masked by the cache', () async {
      // Serving stale grades here would strand the student on a dead session
      // instead of letting the app renew it.
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(gradesProvider.future);

      api.failWith = ApiException('session_expired', statusCode: 401);
      container.invalidate(gradesProvider);

      await expectLater(
        container.read(gradesProvider.future),
        throwsA(isA<ApiException>().having((e) => e.isSessionExpired, 'expired', isTrue)),
      );
    });

    test('a later live fetch replaces the stored copy', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(gradesProvider.future);

      api.label = 'relevé mis à jour';
      container.invalidate(gradesProvider);
      await container.read(gradesProvider.future);

      api.failWith = ApiException('network_error');
      container.invalidate(gradesProvider);

      final grades = await container.read(gradesProvider.future);
      expect(grades.nom, 'relevé mis à jour');
    });
  });
}
