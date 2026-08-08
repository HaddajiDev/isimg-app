import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/core/api_exception.dart';
import 'package:isimg_app/core/schedule_cache.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/providers/schedule_provider.dart';

/// Serves one schedule, then fails however the test asks.
class FlakyApi implements ApiClient {
  ApiException? failWith;
  int scheduleCalls = 0;
  String label = 'semaine en ligne';

  @override
  Future<Schedule> getSchedule({String? week}) async {
    scheduleCalls++;
    final failure = failWith;
    if (failure != null) throw failure;
    return Schedule(weekLabel: label, hasSessions: false);
  }

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
    test('a saved week comes back with its capture time', () async {
      final cache = ScheduleCache();
      await cache.save('2026-08-10', Schedule(weekLabel: 'semaine', hasSessions: true));

      final cached = await cache.read('2026-08-10');
      expect(cached, isNotNull);
      expect(cached!.schedule.weekLabel, 'semaine');
      expect(cached.schedule.hasSessions, isTrue);
      expect(DateTime.now().difference(cached.capturedAt).inSeconds, lessThan(5));
    });

    test('weeks are kept separately', () async {
      final cache = ScheduleCache();
      await cache.save('2026-08-10', Schedule(weekLabel: 'A', hasSessions: false));
      await cache.save('2026-08-17', Schedule(weekLabel: 'B', hasSessions: false));

      expect((await cache.read('2026-08-10'))!.schedule.weekLabel, 'A');
      expect((await cache.read('2026-08-17'))!.schedule.weekLabel, 'B');
    });

    test('an unknown week is a miss', () async {
      expect(await ScheduleCache().read('1999-01-04'), isNull);
    });

    test('a corrupt entry behaves as a miss rather than throwing', () async {
      SharedPreferences.setMockInitialValues({'schedule_v1:2026-08-10': 'not json'});
      expect(await ScheduleCache().read('2026-08-10'), isNull);
    });
  });

  group('offline fallback', () {
    test('a live fetch is stored and reported as live', () async {
      final api = FlakyApi();
      final container = makeContainer(api);

      final view = await container.read(scheduleProvider.future);
      expect(view.isFromCache, isFalse);
      expect(view.schedule.weekLabel, 'semaine en ligne');

      final week = formatWeek(mondayOf(DateTime.now()));
      expect(await ScheduleCache().read(week), isNotNull);
    });

    test('losing the connection serves the saved week', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(scheduleProvider.future);

      // Same week, now offline.
      api.failWith = ApiException('network_error');
      container.invalidate(scheduleProvider);

      final view = await container.read(scheduleProvider.future);
      expect(view.isFromCache, isTrue);
      expect(view.schedule.weekLabel, 'semaine en ligne');
      expect(view.capturedAt, isNotNull);
    });

    test('a timeout also falls back', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(scheduleProvider.future);

      api.failWith = ApiException('upstream_timeout');
      container.invalidate(scheduleProvider);

      expect((await container.read(scheduleProvider.future)).isFromCache, isTrue);
    });

    test('offline with nothing saved still reports the failure', () async {
      final api = FlakyApi()..failWith = ApiException('network_error');
      final container = makeContainer(api);

      await expectLater(
        container.read(scheduleProvider.future),
        throwsA(isA<ApiException>()),
      );
    });

    test('an expired session is never masked by the cache', () async {
      // Serving stale data here would strand the student on a dead session
      // instead of letting the app renew it.
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(scheduleProvider.future);

      api.failWith = ApiException('session_expired', statusCode: 401);
      container.invalidate(scheduleProvider);

      await expectLater(
        container.read(scheduleProvider.future),
        throwsA(isA<ApiException>().having((e) => e.isSessionExpired, 'expired', isTrue)),
      );
    });

    test('a later live fetch replaces the stored copy', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(scheduleProvider.future);

      api.label = 'semaine mise à jour';
      container.invalidate(scheduleProvider);
      await container.read(scheduleProvider.future);

      api.failWith = ApiException('network_error');
      container.invalidate(scheduleProvider);

      final view = await container.read(scheduleProvider.future);
      expect(view.schedule.weekLabel, 'semaine mise à jour');
    });
  });

  group('week selection', () {
    test('any day snaps to that week\'s Monday', () {
      // Saturday 8 August 2026 belongs to the week starting Monday the 3rd.
      expect(mondayOf(DateTime(2026, 8, 8)), DateTime(2026, 8, 3));
      // A Monday stays put.
      expect(mondayOf(DateTime(2026, 8, 3)), DateTime(2026, 8, 3));
      // Sunday belongs to the week that began six days earlier.
      expect(mondayOf(DateTime(2026, 8, 9)), DateTime(2026, 8, 3));
    });

    test('the week key is the Monday in ISO form', () {
      expect(formatWeek(DateTime(2026, 8, 3)), '2026-08-03');
      expect(formatWeek(DateTime(2026, 12, 28)), '2026-12-28');
    });
  });
}
