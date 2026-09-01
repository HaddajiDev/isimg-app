import 'package:flutter_test/flutter_test.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/models/absences.dart';
import 'package:isimg_app/models/exam.dart';
import 'package:isimg_app/models/calendar.dart';
import 'package:isimg_app/models/news.dart';
import 'package:isimg_app/models/notifications.dart';
import 'package:isimg_app/models/stage.dart';
import 'package:isimg_app/models/student.dart';
import 'package:isimg_app/core/demo_api_client.dart';
import 'package:isimg_app/core/demo_data.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';

class RecordingApi implements ApiClient {
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

  int loginCalls = 0;
  int getGradesCalls = 0;
  int getScheduleCalls = 0;
  int getProfileCalls = 0;

  @override
  Future<LoginResult> login(String username, String password) async {
    loginCalls++;
    throw Exception('should not reach the real client');
  }

  @override
  Future<void> verifyOtp({required String session, required String token2fa, required String code}) async {}

  @override
  Future<Grades> getGrades({String? au, String? ss}) async {
    getGradesCalls++;
    return Grades.fromJson({'semesters': <dynamic>[]});
  }

  @override
  Future<Schedule> getSchedule({String? week}) async {
    getScheduleCalls++;
    return Schedule.fromJson({'hasSessions': false});
  }

  @override
  Future<Profile> getProfile() async {
    getProfileCalls++;
    return Profile.fromJson({'years': <dynamic>[]});
  }
}

void main() {
  test('demo credentials log in without touching the real client', () async {
    final recording = RecordingApi();
    final client = DemoAwareApiClient(recording);

    final result = await client.login(demoUsername, demoPassword);

    expect(result, isA<LoginOk>());
    expect(recording.loginCalls, 0);
    expect(client.isDemoSession, isTrue);
  });

  test('every other login is passed straight through', () async {
    final recording = RecordingApi();
    final client = DemoAwareApiClient(recording);

    await expectLater(client.login('2024666', 'real-password'), throwsException);

    expect(recording.loginCalls, 1);
    expect(client.isDemoSession, isFalse);
  });

  test('a demo session serves fabricated data for every screen', () async {
    final recording = RecordingApi();
    final client = DemoAwareApiClient(recording);
    await client.login(demoUsername, demoPassword);

    final grades = await client.getGrades();
    final schedule = await client.getSchedule();
    final profile = await client.getProfile();

    expect(grades.nom, isNotNull);
    expect(grades.semesters, isNotEmpty);
    expect(schedule.hasSessions, isTrue);
    expect(profile.years, isNotEmpty);
    expect(recording.getGradesCalls, 0);
    expect(recording.getScheduleCalls, 0);
    expect(recording.getProfileCalls, 0);
  });

  test('a real session still delegates every read', () async {
    final recording = RecordingApi();
    final client = DemoAwareApiClient(recording);
    try {
      await client.login('2024666', 'real-password');
    } catch (_) {}

    await client.getGrades();
    await client.getSchedule();
    await client.getProfile();

    expect(recording.getGradesCalls, 1);
    expect(recording.getScheduleCalls, 1);
    expect(recording.getProfileCalls, 1);
  });

  test('logging back in with a real password after a demo session drops demo mode',
      () async {
    final recording = RecordingApi();
    final client = DemoAwareApiClient(recording);
    await client.login(demoUsername, demoPassword);
    expect(client.isDemoSession, isTrue);

    try {
      await client.login('2024666', 'real-password');
    } catch (_) {}

    expect(client.isDemoSession, isFalse);
  });
}
