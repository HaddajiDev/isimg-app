import 'api_client.dart';
import 'demo_data.dart';
import '../models/absences.dart';
import '../models/exam.dart';
import '../models/grades.dart';
import '../models/profile.dart';
import '../models/schedule.dart';

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

  @override
  Future<Absences> getAbsences() {
    if (_demoSession) return Future.value(demoAbsences());
    return _delegate.getAbsences();
  }

  @override
  Future<ExamsSchedule> getUpcomingExams() {
    if (_demoSession) return Future.value(demoExams());
    return _delegate.getUpcomingExams();
  }
}
