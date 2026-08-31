import '../models/absences.dart';
import '../models/exam.dart';
import '../models/grades.dart';
import '../models/profile.dart';
import '../models/schedule.dart';

sealed class LoginResult {}

class LoginOk extends LoginResult {}

class LoginOtpRequired extends LoginResult {
  final String session;
  final String token2fa;

  LoginOtpRequired({required this.session, required this.token2fa});
}

abstract interface class ApiClient {
  Future<LoginResult> login(String username, String password);

  Future<void> verifyOtp({
    required String session,
    required String token2fa,
    required String code,
  });

  Future<Grades> getGrades({String? au, String? ss});

  Future<Schedule> getSchedule({String? week});

  Future<Profile> getProfile();

  Future<Absences> getAbsences();

  Future<ExamsSchedule> getUpcomingExams();
}
