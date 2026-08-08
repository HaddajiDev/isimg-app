import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'session_store.dart';
import '../models/grades.dart';
import '../models/profile.dart';
import '../models/schedule.dart';

/// Backend address, overridable at build time:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
///
/// The default only works on the Android emulator, where 10.0.2.2 is an alias
/// for the host machine's localhost. A real phone cannot reach that — it needs
/// the LAN IP of whatever is running the backend, so builds for a device must
/// pass API_BASE_URL.
const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

const _sessionHeader = 'X-Isimg-Session';

sealed class LoginResult {}

class LoginOk extends LoginResult {}

class LoginOtpRequired extends LoginResult {
  /// Interim session and form token the backend hands out instead of keeping
  /// any pending-login state; both go back with the code.
  final String session;
  final String token2fa;

  LoginOtpRequired({required this.session, required this.token2fa});
}

/// Talks to our backend, which translates ISIMG's HTML into JSON.
///
/// Every call carries the stored session and saves whatever comes back, so the
/// device remains the sole holder of the ISIMG credentials.
class ApiClient {
  final Dio _dio = Dio(
    BaseOptions(baseUrl: _baseUrl, connectTimeout: const Duration(seconds: 20)),
  );
  final SessionStore _sessions;

  ApiClient({SessionStore? sessions}) : _sessions = sessions ?? SessionStore();

  Future<LoginResult> login(String username, String password) async {
    // Replay the device token if we still hold one, to avoid a fresh OTP.
    final trustedDevice = SessionStore.trustedDeviceOf(await _sessions.read());

    final res = await _post('/auth/login', {
      'username': username,
      'password': password,
      'trustedDevice': ?trustedDevice,
    });

    final data = res.data as Map<String, dynamic>;
    if (data['status'] == '2fa_required') {
      return LoginOtpRequired(
        session: data['session'] as String,
        token2fa: data['token2fa'] as String,
      );
    }

    await _sessions.save(data['session'] as String);
    return LoginOk();
  }

  Future<void> verifyOtp({
    required String session,
    required String token2fa,
    required String code,
  }) async {
    final res = await _post('/auth/verify-otp', {
      'session': session,
      'token2fa': token2fa,
      'code': code,
    });
    await _sessions.save((res.data as Map<String, dynamic>)['session'] as String);
  }

  /// Omitting [au]/[ss] lets the server use its own current année, which is the
  /// most recent one that actually has data.
  Future<Grades> getGrades({String? au, String? ss}) async {
    final data = await _get('/grades', query: {'au': ?au, 'ss': ?ss});
    return Grades.fromJson(data);
  }

  Future<Schedule> getSchedule({String? week}) async {
    final data = await _get('/schedule', query: {'week': ?week});
    return Schedule.fromJson(data);
  }

  Future<Profile> getProfile() async {
    return Profile.fromJson(await _get('/profile'));
  }

  Future<Response> _post(String path, Map<String, dynamic> body) async {
    try {
      return await _dio.post(path, data: body);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Issues a request with the stored session and persists the refreshed one.
  Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? query}) async {
    final session = await _sessions.read();
    if (session == null) throw ApiException('no_session', statusCode: 401);

    try {
      final res = await _dio.get(
        path,
        queryParameters: query,
        options: Options(headers: {_sessionHeader: session}),
      );
      final data = res.data as Map<String, dynamic>;

      // Cookies rotate per request; losing the update would break the next one.
      final refreshed = data['session'] as String?;
      if (refreshed != null) await _sessions.save(refreshed);

      return data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final code = (e.response?.data is Map)
        ? (e.response?.data['error'] as String? ?? 'unknown_error')
        : 'network_error';
    return ApiException(code, statusCode: e.response?.statusCode);
  }
}
