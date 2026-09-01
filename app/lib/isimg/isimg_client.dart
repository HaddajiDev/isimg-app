import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/session_store.dart';
import '../models/absences.dart';
import '../models/calendar.dart';
import '../models/exam.dart';
import '../models/news.dart';
import '../models/notifications.dart';
import '../models/stage.dart';
import '../models/student.dart';
import '../models/grades.dart';
import '../models/profile.dart';
import '../models/schedule.dart';
import 'cookies.dart';
import 'isimg_parser.dart';

const _base = 'https://isimg.rnu.tn';
const _homeUrl = '$_base/fra/home';
const _checkAccountUrl = '$_base/fra/intranet/check_account';
const _verify2faUrl = '$_base/fra/intranet/verify_2fa';
const _rdnUrl = '$_base/fra/intranet/etudiant/rdn';
const _emploiUrl = '$_base/fra/intranet/etudiant/emploi';

const _cursusUrl = '$_base/fra/intranet/etu/moncursus';

class IsimgClient implements ApiClient {
  final Dio _dio;
  final SessionStore _sessions;
  final IsimgParser _parser;

  IsimgClient({Dio? dio, SessionStore? sessions, IsimgParser parser = const IsimgParser()})
      : _dio = dio ?? Dio(),
        _sessions = sessions ?? SessionStore(),
        _parser = parser {
    _dio.options
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 30)

      ..validateStatus = ((_) => true)
      ..followRedirects = true
      ..headers = {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/151.0.0.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
      };
  }

  Future<Response<String>> _send(
    String url, {
    Map<String, String>? form,
    required Cookies cookies,
  }) async {
    final headers = <String, String>{
      if (cookies.header.isNotEmpty) 'Cookie': cookies.header,
      if (form != null) ...{
        'Content-Type': 'application/x-www-form-urlencoded',

        'Origin': 'null',
      },
    };

    final Response<String> response;
    try {
      response = form == null
          ? await _dio.get<String>(url, options: Options(headers: headers))
          : await _dio.post<String>(
              url,
              data: form.entries
                  .map((e) =>
                      '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
                  .join('&'),
              options: Options(headers: headers),
            );
    } on DioException catch (e) {
      throw ApiException(
        e.type == DioExceptionType.connectionError ? 'network_error' : 'upstream_timeout',
      );
    }

    final setCookies = response.headers.map['set-cookie'];
    if (setCookies != null) cookies.applySetCookies(setCookies);

    return response;
  }

  String _body(Response<String> response) => response.data ?? '';

  Future<Cookies> _storedCookies() async => Cookies.decode(await _sessions.read());

  Future<void> _persist(Cookies cookies) => _sessions.save(cookies.encode());

  String? _extractInput(String html, String name) {
    final match = RegExp('name=["\']$name["\']\\s+value=["\']([^"\']+)["\']')
        .firstMatch(html);
    return match?[1];
  }

  String? _extractMetaRefreshUrl(String html) {
    final match = RegExp(
      r'''<meta[^>]+http-equiv=["']refresh["'][^>]+content=["'][^;]+;\s*URL=([^"'>\s]+)["']?''',
      caseSensitive: false,
    ).firstMatch(html);
    return match?[1];
  }

  @override
  Future<LoginResult> login(String username, String password) async {
    final previous = await _storedCookies();
    final cookies = Cookies();
    final trusted = previous.trustedDevice;
    if (trusted != null) cookies.set('trusted_device', trusted);

    final home = _body(await _send(_homeUrl, cookies: cookies));
    final token = _extractInput(home, 'token');
    if (token == null) throw ApiException('login_token_not_found');

    final loginBody = _body(await _send(
      _checkAccountUrl,
      cookies: cookies,
      form: {'token': token, 'username': username, 'password': password},
    ));

    if (_parser.looksLikeLoginPage(loginBody)) {
      throw ApiException('invalid_credentials', statusCode: 401);
    }

    final redirect = _extractMetaRefreshUrl(loginBody);
    if (redirect == null) throw ApiException('invalid_credentials', statusCode: 401);

    if (redirect.contains('changepwd')) {
      throw ApiException('password_expired', statusCode: 403);
    }

    if (redirect.contains('verify_2fa')) {
      final otpPage = _body(await _send(
        Uri.parse(_base).resolve(redirect).toString(),
        cookies: cookies,
      ));
      final token2fa = _extractInput(otpPage, 'token2fa');
      if (token2fa == null) throw ApiException('otp_token_not_found');
      return LoginOtpRequired(session: cookies.encode(), token2fa: token2fa);
    }

    await _persist(cookies);
    return LoginOk();
  }

  @override
  Future<void> verifyOtp({
    required String session,
    required String token2fa,
    required String code,
  }) async {
    final cookies = Cookies.decode(session);

    final body = _body(await _send(
      _verify2faUrl,
      cookies: cookies,

      form: {'token2fa': token2fa, 'code': code, 'remember_device': 'on'},
    ));

    final redirect = _extractMetaRefreshUrl(body);
    if (redirect == null || redirect.contains('verify_2fa')) {
      throw ApiException('invalid_otp', statusCode: 401);
    }

    await _persist(cookies);
  }

  @override
  Future<Grades> getGrades({String? au, String? ss}) async {
    final cookies = await _requireCookies();

    Future<String> load(String auCode, String ssCode) async => _body(await _send(
          _rdnUrl,
          cookies: cookies,

          form: {'f_au': auCode, 'f_ss': ssCode},
        ));

    final probe = _body(await _send(_rdnUrl, cookies: cookies));
    _guard(probe, _parser.looksLikeGradesPage);

    final options = _parser.parseGrades(probe);
    final session = ss ?? _parser.selectedCode(options.sessions) ?? '1';
    var annee = au ?? _parser.selectedCode(options.annees);
    String? body;

    if (annee != null) {
      body = await load(annee, session);
    } else {
      for (final option in options.annees) {
        final candidate = await load(option.code, session);
        if (_parser.isUnauthorized(candidate)) {
          throw ApiException('session_expired', statusCode: 401);
        }
        final published = _parser.parseGrades(candidate).moyenneGenerale != null;
        if (published || body == null) {
          annee = option.code;
          body = candidate;
        }
        if (published) break;
      }
    }

    if (body == null) throw ApiException('unexpected_upstream_response');
    _guard(body, _parser.looksLikeGradesPage);
    await _persist(cookies);

    return _parser.parseGrades(body, currentAu: annee, currentSs: session);
  }

  @override
  Future<Schedule> getSchedule({String? week}) async {
    final cookies = await _requireCookies();

    final url = (week != null && week.isNotEmpty) ? '$_emploiUrl/$week/0' : _emploiUrl;

    final body = _body(await _send(url, cookies: cookies));
    _guard(body, _parser.looksLikeSchedulePage);
    await _persist(cookies);

    return _parser.parseSchedule(body);
  }

  @override
  Future<Profile> getProfile() async {
    final cookies = await _requireCookies();

    final body = _body(await _send(_cursusUrl, cookies: cookies));
    _guard(body, _parser.looksLikeCursusPage);
    await _persist(cookies);

    return _parser.parseCursus(body);
  }

  @override
  Future<Absences> getAbsences() async => throw ApiException('unsupported');

  @override
  Future<ExamsSchedule> getUpcomingExams() async => throw ApiException('unsupported');

  @override
  Future<UniversityCalendar> getUniversityCalendar() async => throw ApiException('unsupported');

  @override
  Future<StudentInfo> getStudentDetails() async => throw ApiException('unsupported');

  @override
  Future<NewsFeed> getNews() async => throw ApiException('unsupported');

  @override
  Future<NotifData> getNotifications() async => throw ApiException('unsupported');

  @override
  Future<Stages> getStages() async => throw ApiException('unsupported');

  Future<Cookies> _requireCookies() async {
    final cookies = await _storedCookies();
    if (cookies.isEmpty) throw ApiException('no_session', statusCode: 401);
    return cookies;
  }

  void _guard(String body, bool Function(String) looksRight) {
    if (_parser.isUnauthorized(body)) {
      throw ApiException('session_expired', statusCode: 401);
    }
    if (!looksRight(body)) {
      throw ApiException('session_expired', statusCode: 401);
    }
  }
}
