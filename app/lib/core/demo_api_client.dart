import 'api_client.dart';
import 'api_exception.dart';
import 'demo_data.dart';
import 'services_api.dart';
import '../models/demande.dart';
import '../models/pfe.dart';
import '../models/absences.dart';
import '../models/calendar.dart';
import '../models/exam.dart';
import '../models/stage.dart';
import '../models/student.dart';
import '../models/grades.dart';
import '../models/profile.dart';
import '../models/schedule.dart';

class DemoAwareApiClient implements ApiClient, ServicesApi {
  final ApiClient _delegate;
  bool _demoSession = false;
  final _demoDemandes = <Demande>[];

  ServicesApi get _services {
    final d = _delegate;
    if (d is ServicesApi) return d as ServicesApi;
    throw ApiException('unsupported');
  }

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

  @override
  Future<UniversityCalendar> getUniversityCalendar() {
    if (_demoSession) return Future.value(demoUniversityCalendar());
    return _delegate.getUniversityCalendar();
  }

  @override
  Future<StudentInfo> getStudentDetails() {
    if (_demoSession) return Future.value(demoStudentInfo());
    return _delegate.getStudentDetails();
  }

  @override
  Future<Stages> getStages() {
    if (_demoSession) return Future.value(demoStages());
    return _delegate.getStages();
  }

  @override
  Future<List<DemandeModel>> getDemandeModels() async {
    if (_demoSession) return demoDemandeModels();
    return _services.getDemandeModels();
  }

  @override
  Future<List<Demande>> getDemandes() async {
    if (_demoSession) return List.of(_demoDemandes);
    return _services.getDemandes();
  }

  @override
  Future<List<DemandeMessage>> getDemandeMessages(String demandeId) async {
    if (_demoSession) return const [];
    return _services.getDemandeMessages(demandeId);
  }

  @override
  Future<void> addDemande(DemandeModel model, Map<String, String> values) async {
    if (!_demoSession) return _services.addDemande(model, values);
    _demoDemandes.insert(
      0,
      Demande(
        id: 'demo-${_demoDemandes.length + 1}',
        modeleId: model.id,
        name: model.name,
        statut: DemandeStatut.enCours,
        values: [
          for (final f in model.fields)
            if ((values[f.id] ?? '').isNotEmpty) DemandeValue(label: f.label, value: values[f.id]!),
        ],
        created: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deleteDemande(String demandeId) async {
    if (!_demoSession) return _services.deleteDemande(demandeId);
    _demoDemandes.removeWhere((d) => d.id == demandeId);
  }

  @override
  Future<void> addDemandeMessage(String demandeId, String message) async {
    if (!_demoSession) return _services.addDemandeMessage(demandeId, message);
  }

  @override
  Future<void> markDemandeSeen(String demandeId) async {
    if (!_demoSession) return _services.markDemandeSeen(demandeId);
  }

  @override
  Future<Pfe?> getPfe() async {
    if (_demoSession) return null;
    return _services.getPfe();
  }
}
