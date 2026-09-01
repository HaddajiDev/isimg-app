import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isimg_app/core/absences_cache.dart';
import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/core/api_exception.dart';
import 'package:isimg_app/core/exams_cache.dart';
import 'package:isimg_app/models/absences.dart';
import 'package:isimg_app/models/exam.dart';
import 'package:isimg_app/models/calendar.dart';
import 'package:isimg_app/models/news.dart';
import 'package:isimg_app/models/notifications.dart';
import 'package:isimg_app/models/stage.dart';
import 'package:isimg_app/models/student.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/absences_provider.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/providers/exams_provider.dart';

Absences _absences(int nbre) => Absences(
      currentSemestre: 1,
      s1: SemestreAbsences(
        semestre: 1,
        nbreGlobal: nbre,
        matieres: const [MatiereAbsence(module: 'Algo', taux: 5)],
      ),
    );

ExamsSchedule _exams(String matiere) => ExamsSchedule(exams: [Exam(matiere: matiere)]);

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

  ApiException? failWith;
  int absCalls = 0;
  int examCalls = 0;

  @override
  Future<Absences> getAbsences() async {
    absCalls++;
    if (failWith != null) throw failWith!;
    return _absences(3);
  }

  @override
  Future<ExamsSchedule> getUpcomingExams() async {
    examCalls++;
    if (failWith != null) throw failWith!;
    return _exams('Big Data');
  }

  @override
  Future<Grades> getGrades({String? au, String? ss}) async => Grades.fromJson({'semesters': <dynamic>[]});
  @override
  Future<Schedule> getSchedule({String? week}) async => Schedule(hasSessions: false);
  @override
  Future<Profile> getProfile() async => Profile.fromJson({'years': <dynamic>[]});
  @override
  Future<LoginResult> login(String username, String password) async => LoginOk();
  @override
  Future<void> verifyOtp({required String session, required String token2fa, required String code}) async {}
}

class _AuthedNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

ProviderContainer makeContainer(FlakyApi api) {
  final container = ProviderContainer(overrides: [
    apiClientProvider.overrideWithValue(api),
    authProvider.overrideWith(() => _AuthedNotifier()),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AbsencesCache store', () {
    test('a saved bilan comes back with its capture time', () async {
      final cache = AbsencesCache();
      await cache.save(_absences(3));
      final cached = await cache.read();
      expect(cached, isNotNull);
      expect(cached!.absences.totalAbsences, 3);
      expect(DateTime.now().difference(cached.capturedAt).inSeconds, lessThan(5));
    });

    test('empty is a miss; corrupt is a miss', () async {
      expect(await AbsencesCache().read(), isNull);
      SharedPreferences.setMockInitialValues({'absences_v1': 'not json'});
      expect(await AbsencesCache().read(), isNull);
    });
  });

  group('ExamsCache store', () {
    test('a saved schedule comes back with its capture time', () async {
      final cache = ExamsCache();
      await cache.save(_exams('Réseaux'));
      final cached = await cache.read();
      expect(cached, isNotNull);
      expect(cached!.exams.exams.single.matiere, 'Réseaux');
      expect(DateTime.now().difference(cached.capturedAt).inSeconds, lessThan(5));
    });

    test('empty is a miss; corrupt is a miss', () async {
      expect(await ExamsCache().read(), isNull);
      SharedPreferences.setMockInitialValues({'exams_v1': 'not json'});
      expect(await ExamsCache().read(), isNull);
    });
  });

  group('absences offline fallback', () {
    test('a live fetch is stored and reported as live (no capturedAt)', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      final view = await container.read(absencesProvider.future);
      expect(view.absences.totalAbsences, 3);
      expect(view.capturedAt, isNull);
      expect(await AbsencesCache().read(), isNotNull);
    });

    test('losing the connection serves the cached bilan, flagged offline', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(absencesProvider.future);

      api.failWith = ApiException('network_error');
      container.invalidate(absencesProvider);
      final view = await container.read(absencesProvider.future);
      expect(view.absences.totalAbsences, 3);
      expect(view.capturedAt, isNotNull);
    });

    test('a non-connectivity error is not masked by the cache', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(absencesProvider.future);

      api.failWith = ApiException('session_expired', statusCode: 401);
      container.invalidate(absencesProvider);
      await expectLater(container.read(absencesProvider.future), throwsA(isA<ApiException>()));
    });

    test('offline with nothing saved still reports the failure', () async {
      final api = FlakyApi()..failWith = ApiException('network_error');
      final container = makeContainer(api);
      await expectLater(container.read(absencesProvider.future), throwsA(isA<ApiException>()));
    });
  });

  group('exams offline fallback', () {
    test('a live fetch is stored and reported as live (no capturedAt)', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      final view = await container.read(examsProvider.future);
      expect(view.schedule.exams.single.matiere, 'Big Data');
      expect(view.capturedAt, isNull);
    });

    test('a timeout serves the cached schedule, flagged offline', () async {
      final api = FlakyApi();
      final container = makeContainer(api);
      await container.read(examsProvider.future);

      api.failWith = ApiException('upstream_timeout');
      container.invalidate(examsProvider);
      final view = await container.read(examsProvider.future);
      expect(view.schedule.exams.single.matiere, 'Big Data');
      expect(view.capturedAt, isNotNull);
    });
  });
}
