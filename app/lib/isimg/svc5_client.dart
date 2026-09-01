import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/credential_store.dart';
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
import 'svc5_crypto.dart';
import 'svc5_mapper.dart';
import 'svc5_session.dart';

class Svc5Client implements ApiClient {
  static const _base = 'https://isimg.rnu.tn/svc5/';
  static const _sqlToken =
      'fAKs3F5SG4wlaOZkrmHe6JvVDyNqgth2T9CcYE01L7xPXIQnb8pRjdWUMzoBui';
  static const _saltCs = 'gbh4KdOxMhda7I5l';
  static const _saltSc = 'HAUlSIp9lMniD9lo';
  static const _appVersion = '12.7';
  static const _institut = '1';

  static const _qLoadConfig = 1;
  static const _qLoadAnneesUniv = 2;
  static const _qGetEtuEdT = 8;
  static const _qGetCalUniv = 4;
  static const _qGetNews = 5;
  static const _qGetStage = 38;
  static const _qGetNotifs = 68;
  static const _qGetProfileEtu = 9;
  static const _qGetReleveNotes = 65;
  static const _qGetAbsencesEtu = 66;
  static const _qGetNextExams = 69;

  static const _newsCount = '30';
  static const _maxNotifs = '30';

  final Dio _dio;
  final SessionStore _sessions;
  final CredentialStore _credentials;

  Svc5Client({Dio? dio, SessionStore? sessions, CredentialStore? credentials})
      : _dio = dio ?? Dio(),
        _sessions = sessions ?? SessionStore(),
        _credentials = credentials ?? CredentialStore() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 30)

      ..validateStatus = ((_) => true);
  }

  Future<String> _post(String file, Map<String, String> fields) async {
    try {
      final res = await _dio.post<String>(
        '$_base$file',
        data: fields.entries
            .map((e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
            .join('&'),
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          responseType: ResponseType.plain,
        ),
      );
      return res.data ?? '';
    } on DioException catch (e) {
      throw ApiException(
        e.type == DioExceptionType.connectionError ? 'network_error' : 'upstream_timeout',
      );
    }
  }

  Future<List<dynamic>?> _rawQueryWith(
    String utoken,
    String userId,
    int req,
    Map<String, String> args,
  ) async {
    final payload = Svc5Crypto.encrypt(jsonEncode(args), utoken);
    final raw = await _post('api', {
      'id': userId,
      'tk': utoken,
      'req': '$req',
      'args': payload,
    });
    final plain = Svc5Crypto.tryDecrypt(raw, utoken);
    if (plain == null) return null;
    final decoded = jsonDecode(plain);
    return decoded is List ? decoded : const [];
  }

  Future<List<dynamic>> _query(int req, Map<String, String> args) async {
    var session = await _requireSession();
    var result = await _rawQueryWith(session.utoken, session.userId, req, args);
    if (result == null && await _reauth()) {
      session = await _requireSession();
      result = await _rawQueryWith(session.utoken, session.userId, req, args);
    }
    if (result == null) throw ApiException('session_expired', statusCode: 401);
    return result;
  }

  Future<Svc5Session> _requireSession() async {
    final session = Svc5Session.tryDecode(await _sessions.read());
    if (session == null) throw ApiException('no_session', statusCode: 401);
    return session;
  }

  @override
  Future<LoginResult> login(String username, String password) async {
    final raw = await _loginRaw(username, password);
    if (!raw.auth) throw ApiException('invalid_credentials', statusCode: 401);

    if (raw.passwordExpired) throw ApiException('password_expired', statusCode: 403);

    await _bootstrapAndStore(raw.utoken, raw.userId);
    return LoginOk();
  }

  @override
  Future<void> verifyOtp({
    required String session,
    required String token2fa,
    required String code,
  }) async {
    throw ApiException('otp_not_supported');
  }

  Future<_LoginRaw> _loginRaw(String username, String password) async {
    final args = Svc5Crypto.encrypt(
      jsonEncode({
        'username': username,
        'password': password,
        'version': _appVersion,
        'ui': '2',
      }),
      _saltCs,
    );
    final raw = await _post('clg', {'token': _sqlToken, 'args': args});
    final plain = Svc5Crypto.tryDecrypt(raw, _saltSc);
    if (plain == null) throw ApiException('invalid_credentials', statusCode: 401);

    final json = jsonDecode(plain) as Map<String, dynamic>;
    return _LoginRaw(
      auth: json['auth']?.toString() == '1',
      utoken: json['token']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      passwordExpired: json['pwdchange']?.toString() == '1' ||
          json['pwdChange']?.toString() == '1',
    );
  }

  Future<bool> _reauth() async {
    final creds = await _credentials.read();
    if (creds == null) return false;
    try {
      final raw = await _loginRaw(creds.username, creds.password);
      if (!raw.auth || raw.passwordExpired) return false;
      final current = Svc5Session.tryDecode(await _sessions.read());
      if (current == null) {
        await _bootstrapAndStore(raw.utoken, raw.userId);
      } else {
        await _sessions
            .save(current.copyWith(utoken: raw.utoken, userId: raw.userId).encode());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _bootstrapAndStore(String utoken, String userId) async {
    final prof = _first(await _rawQueryWith(utoken, userId, _qGetProfileEtu, {'id': userId}));
    final cfg = _first(await _rawQueryWith(utoken, userId, _qLoadConfig, {'instId': _institut}));
    final au = int.tryParse(cfg?['annee_univ']?.toString() ?? '') ?? 0;
    final ann = _first(await _rawQueryWith(utoken, userId, _qLoadAnneesUniv, {'au': '$au'}));
    final firstYear = int.tryParse(ann?['au']?.toString() ?? '') ?? au;

    final session = Svc5Session(
      utoken: utoken,
      userId: userId,
      nce: prof?['nce']?.toString() ?? '',
      classeId: prof?['classe']?.toString() ?? '',
      gid: prof?['groupe_tp']?.toString() ?? '0',
      sexe: prof?['sexe']?.toString() ?? '0',
      au: au,
      yearBase: firstYear - au,
      tauxElimination: double.tryParse(cfg?['taux_elimination']?.toString() ?? '') ?? 20,
      slots: Svc5Mapper.parseSlots(ann?['seances_s1']?.toString()),
      ramadanSlots: Svc5Mapper.parseSlots(ann?['seances_ramadan']?.toString()),
      ramadanStart: ann?['debut_ramadan']?.toString(),
      ramadanEnd: ann?['fin_ramadan']?.toString(),
      prenom: prof?['prenom']?.toString(),
      nom: prof?['nom']?.toString(),
      cin: prof?['cin']?.toString(),
      filiere: prof?['diplome']?.toString(),
      niveau: prof?['niveau']?.toString(),
    );
    await _sessions.save(session.encode());
  }

  @override
  Future<Profile> getProfile() async {
    final session = await _requireSession();
    final prof = _first(await _query(_qGetProfileEtu, {'id': session.userId}));
    if (prof == null) throw ApiException('session_expired', statusCode: 401);

    final years = await _reconstructCursus(
      session,
      currentNiveau: prof['niveau']?.toString(),
      currentClasse: prof['classe_name']?.toString(),
    );
    return Svc5Mapper.mapProfile(prof, years: years);
  }

  @override
  Future<Grades> getGrades({String? au, String? ss}) async {
    final session = await _requireSession();
    final auCode = au ?? '${session.au}';
    final ssCode = ss ?? '1';

    var releve = _first(await _query(_qGetReleveNotes, {
      'nce': session.nce,
      'classe_id': session.classeId,
      'au': auCode,
      'sexe': session.sexe,
    }));

    if (releve != null && auCode == '${session.au}') {
      final mats = releve['matieres'];
      final needsSlots = mats is List &&
          mats.whereType<Map>().any((m) => (m['epreuves'] as List?)?.isEmpty ?? true);
      if (needsSlots) {
        final template = await _findEpreuveTemplate(session);
        if (template != null) {
          releve = {
            ...releve,
            'matieres': Svc5Mapper.graftEpreuveTemplates(mats, template),
          };
        }
      }
    }

    final annees = _anneeOptions(session, auCode);
    final sessions = _sessionOptions(ssCode);
    if (releve == null) {
      return Grades(annees: annees, sessions: sessions, currentAu: auCode, currentSs: ssCode);
    }

    final fullName = [session.prenom, session.nom].whereType<String>().join(' ').trim();
    return Svc5Mapper.mapGrades(
      releve,
      au: auCode,
      ss: ssCode,
      nom: fullName.isEmpty ? null : fullName,
      cin: session.cin,
      filiere: session.filiere,
      niveau: session.niveau,
      annees: annees,
      sessions: sessions,
    );
  }

  @override
  Future<Schedule> getSchedule({String? week}) async {
    final session = await _requireSession();
    final from = (week != null && week.isNotEmpty) ? week : _mondayOfToday();
    final to = _addDays(from, 6);

    final cells = await _query(_qGetEtuEdT, {
      'au': '${session.au}',
      'gid': session.gid,
      'classe_id': session.classeId,
      'nce': session.nce,
      'from': from,
      'to': to,
    });

    return Svc5Mapper.mapSchedule(cells, slots: _slotsFor(session, from));
  }

  @override
  Future<Absences> getAbsences() async {
    final session = await _requireSession();
    final record = _first(await _query(_qGetAbsencesEtu, {'nce': session.nce}));
    if (record == null) {
      return Absences(matiereThreshold: session.tauxElimination);
    }

    return Absences.fromJson(record).copyWith(matiereThreshold: session.tauxElimination);
  }

  @override
  Future<ExamsSchedule> getUpcomingExams() async {
    final session = await _requireSession();
    final rows = await _query(_qGetNextExams, {'nce': session.nce, 'au': '${session.au}'});
    final exams = rows
        .whereType<Map<String, dynamic>>()
        .map(Exam.fromJson)
        .toList()
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return ExamsSchedule(exams: exams);
  }

  @override
  Future<UniversityCalendar> getUniversityCalendar() async {
    final session = await _requireSession();
    final rows = await _query(_qGetCalUniv, {
      'user_type': '1',
      'au': '${session.au}',
      'classe_id': session.classeId,
    });
    final events = rows.whereType<Map<String, dynamic>>().map(CalendarEvent.fromJson).toList()
      ..sort((a, b) {
        final byDate = a.sortKey.compareTo(b.sortKey);
        return byDate != 0 ? byDate : a.ordre.compareTo(b.ordre);
      });
    return UniversityCalendar(events: events);
  }

  @override
  Future<StudentInfo> getStudentDetails() async {
    final session = await _requireSession();
    final prof = _first(await _query(_qGetProfileEtu, {'id': session.userId}));
    if (prof == null) throw ApiException('session_expired', statusCode: 401);
    return StudentInfo.fromJson(prof);
  }

  @override
  Future<NewsFeed> getNews() async {
    final session = await _requireSession();
    final rows = await _query(_qGetNews, {
      'user_type': '1',
      'user_id': session.userId,
      'nbre': _newsCount,
      'sdate': _now(),
      'groupe_id': session.gid,
      'classe_id': session.classeId,
    });
    final items = rows.whereType<Map<String, dynamic>>().map(NewsItem.fromJson).toList()
      ..sort((a, b) =>
          (b.created ?? DateTime(0)).compareTo(a.created ?? DateTime(0)));
    return NewsFeed(items: items);
  }

  @override
  Future<NotifData> getNotifications() async {
    final session = await _requireSession();
    final record = _first(await _query(_qGetNotifs, {
      'id': session.userId,
      'date_limite_news': _epoch(),
      'date_limite_demandes': _epoch(),
      'date_limite_absences': _epoch(),
      'au': '${session.au}',
      'MaxPostsNotifs': _maxNotifs,
    }));
    if (record == null) return const NotifData();
    return NotifData.fromJson(record);
  }

  @override
  Future<Stages> getStages() async {
    final session = await _requireSession();
    final results = await Future.wait(StageType.values.map((type) async {
      try {
        final rec = _first(await _query(_qGetStage, {
          'nce': session.nce,
          'type': '${type.code}',
        }));
        return rec == null ? null : Stage.fromJson(rec, type: type);
      } catch (_) {
        return null;
      }
    }));
    return Stages(stages: results.whereType<Stage>().toList());
  }

  Future<List<dynamic>?> _findEpreuveTemplate(Svc5Session session) async {
    for (var id = session.au - 1; id >= session.au - 3 && id > 0; id--) {
      final rec = _first(await _query(_qGetReleveNotes, {
        'nce': session.nce,
        'classe_id': session.classeId,
        'au': '$id',
        'sexe': session.sexe,
      }));
      final mats = rec?['matieres'];
      if (mats is List &&
          mats.whereType<Map>().any((m) => (m['epreuves'] as List?)?.isNotEmpty ?? false)) {
        return mats;
      }
    }
    return null;
  }

  Future<List<CursusYear>> _reconstructCursus(
    Svc5Session session, {
    String? currentNiveau,
    String? currentClasse,
  }) async {
    if (session.au <= 0) return const [];
    final span = _yearSpan(currentNiveau ?? session.niveau);
    final ids = [for (var id = session.au; id > session.au - span && id > 0; id--) id];

    final rows = await Future.wait(ids.map((id) async {
      try {
        final rec = _first(await _query(_qGetReleveNotes, {
          'nce': session.nce,
          'classe_id': session.classeId,
          'au': '$id',
          'sexe': session.sexe,
        }));
        final res = rec?['resultats'] as Map<String, dynamic>?;
        if (res == null) return null;
        final resultat = _clean(res['resultat_p']);
        final moyenne = _clean(res['moyenne_p']);
        final credits = _clean(res['credits_p']);

        if (resultat == null && moyenne == null) return null;
        final isCurrent = id == session.au;

        final currentN = int.tryParse(currentNiveau ?? '');
        final niveau = isCurrent
            ? currentNiveau
            : (currentN != null ? '${(currentN - (session.au - id)).clamp(1, 99)}' : null);
        return CursusYear(
          annee: session.labelFor(id),
          niveau: niveau,
          classe: isCurrent ? currentClasse : null,

          numeroInscription: session.nce,
          moyenne: moyenne,
          credits: credits,
          resultat: resultat,
        );
      } catch (_) {
        return null;
      }
    }));

    return rows.whereType<CursusYear>().toList();
  }

  List<SelectOption> _anneeOptions(Svc5Session session, String selected) {
    if (session.au <= 0) return const [];
    final span = _yearSpan(session.niveau);
    return [
      for (var id = session.au; id > session.au - span && id > 0; id--)
        SelectOption(code: '$id', label: session.labelFor(id), selected: '$id' == selected),
    ];
  }

  List<SelectOption> _sessionOptions(String selected) => [
        SelectOption(code: '1', label: 'Principale', selected: selected == '1'),
        SelectOption(code: '2', label: 'Contrôle', selected: selected == '2'),
      ];

  int _yearSpan(String? niveau) {
    final n = int.tryParse(niveau ?? '') ?? 3;
    return n.clamp(1, 6);
  }

  List<String> _slotsFor(Svc5Session session, String date) {
    final start = session.ramadanStart, end = session.ramadanEnd;
    if (session.ramadanSlots.isNotEmpty &&
        start != null && end != null &&
        start.compareTo(date) <= 0 && date.compareTo(end) <= 0) {
      return session.ramadanSlots;
    }
    return session.slots;
  }

  static Map<String, dynamic>? _first(List<dynamic>? list) {
    if (list == null || list.isEmpty) return null;
    final first = list.first;
    return first is Map<String, dynamic> ? first : null;
  }

  static String? _clean(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return (s.isEmpty || s == '0') ? null : s;
  }

  static String _mondayOfToday() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    return _fmt(monday);
  }

  static String _addDays(String isoDate, int days) {
    final parts = isoDate.split('-').map(int.parse).toList();
    final d = DateTime(parts[0], parts[1], parts[2]).add(Duration(days: days));
    return _fmt(d);
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _dateTime(DateTime d) =>
      '${_fmt(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  static String _now() => _dateTime(DateTime.now());

  static String _epoch() => '2000-01-01 00:00:00';
}

class _LoginRaw {
  final bool auth;
  final String utoken;
  final String userId;
  final bool passwordExpired;
  _LoginRaw({required this.auth, required this.utoken, required this.userId, required this.passwordExpired});
}
