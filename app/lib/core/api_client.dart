import '../models/grades.dart';
import '../models/profile.dart';
import '../models/schedule.dart';

sealed class LoginResult {}

class LoginOk extends LoginResult {}

class LoginOtpRequired extends LoginResult {
  /// Interim cookies and form token to send back with the emailed code.
  final String session;
  final String token2fa;

  LoginOtpRequired({required this.session, required this.token2fa});
}

/// What the app needs of ISIMG, independent of how it is reached.
///
/// Implemented by [IsimgClient], which talks to the site directly from the
/// phone; kept as an interface so tests can substitute a fake.
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
}
