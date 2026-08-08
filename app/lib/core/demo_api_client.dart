import 'api_client.dart';
import 'demo_data.dart';
import '../models/grades.dart';
import '../models/profile.dart';
import '../models/schedule.dart';

/// Wraps the real [ApiClient] and diverts a fixed demo login to fabricated
/// data instead of the network. Exists so Play Store reviewers — who cannot
/// receive the emailed 2FA code sent to a real student's inbox — have a
/// working account to review the app with.
///
/// Every other username and password is passed straight through to ISIMG.
class DemoAwareApiClient implements ApiClient {
  final ApiClient _delegate;
  bool _demoSession = false;

  DemoAwareApiClient(this._delegate);

  bool get isDemoSession => _demoSession;

  @override
  Future<LoginResult> login(String username, String password) async {
    if (username.trim() == demoUsername && password == demoPassword) {
      _demoSession = true;
      return LoginOk();
    }
    _demoSession = false;
    return _delegate.login(username, password);
  }

  @override
  Future<void> verifyOtp({
    required String session,
    required String token2fa,
    required String code,
  }) {
    return _delegate.verifyOtp(session: session, token2fa: token2fa, code: code);
  }

  @override
  Future<Grades> getGrades({String? au, String? ss}) {
    if (_demoSession) return Future.value(demoGrades(au: au, ss: ss));
    return _delegate.getGrades(au: au, ss: ss);
  }

  @override
  Future<Schedule> getSchedule({String? week}) {
    if (_demoSession) return Future.value(demoSchedule(week: week));
    return _delegate.getSchedule(week: week);
  }

  @override
  Future<Profile> getProfile() {
    if (_demoSession) return Future.value(demoProfile());
    return _delegate.getProfile();
  }
}
