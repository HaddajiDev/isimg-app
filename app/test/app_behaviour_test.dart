import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/screens/home_screen.dart';
import 'package:isimg_app/theme/app_theme.dart';
import 'package:isimg_app/widgets/student_avatar.dart';
import 'package:isimg_app/widgets/version_footer.dart';

/// Stands in for the backend so widget tests never touch the network.
class FakeApiClient implements ApiClient {
  String? lastAu;
  String? lastSs;
  int gradesCallCount = 0;
  final requestedWeeks = <String?>[];

  @override
  Future<LoginResult> login(String username, String password) async => LoginOk();

  @override
  Future<void> verifyOtp({required String session, required String token2fa, required String code}) async {}

  @override
  Future<Grades> getGrades({String? au, String? ss}) async {
    lastAu = au;
    lastSs = ss;
    gradesCallCount++;
    return Grades.fromJson({
      'nom': 'Haddaji Ahmed',
      'niveau': '1',
      'moyenneGenerale': '10.56',
      'credits': '46',
      'semesters': [
        {
          'semestre': '1',
          'unites': [
            {
              'libelle': 'Uef110 : mathématique 1',
              'coefficient': 3,
              'credits': 6,
              'moyenne': 5.93,
              'matieres': [
                {
                  'libelle': 'Algèbre 1',
                  'regime': 'RM',
                  'coefficient': 1.5,
                  'credits': 3,
                  'moyenne': 6.5,
                  'epreuves': [
                    {'libelle': 'DS (0.3)', 'poids': 0.3, 'note': 10},
                    {'libelle': 'Ex (0.7)', 'poids': 0.7, 'note': 5},
                  ],
                },
                // No published average: the app must derive 12.0 from the DS
                // alone and mark it as a partial estimate.
                {
                  'libelle': 'Analyse 1',
                  'regime': 'RM',
                  'coefficient': 1.5,
                  'credits': 3,
                  'moyenne': null,
                  'epreuves': [
                    {'libelle': 'DS (0.3)', 'poids': 0.3, 'note': 12},
                    {'libelle': 'Ex (0.7)', 'poids': 0.7, 'note': null},
                  ],
                },
              ],
            },
          ],
        },
      ],
      // Newest first. Note nothing is flagged `selected` — that mirrors the
      // real page, which is why currentAu is the authoritative field.
      'annees': [
        {'code': '13', 'label': '2026-2027', 'selected': false},
        {'code': '12', 'label': '2025-2026', 'selected': false},
        {'code': '11', 'label': '2024-2025', 'selected': false},
      ],
      'sessions': [
        {'code': '1', 'label': 'Principale', 'selected': false},
        {'code': '2', 'label': 'Contrôle', 'selected': false},
      ],
      'currentAu': au ?? '12',
      'currentSs': ss ?? '1',
    });
  }

  @override
  Future<Profile> getProfile() async {
    // Mirrors the real /profile payload, keys and accents included.
    return Profile.fromJson({
      'prenom': 'Ahmed',
      'nom': 'Haddaji',
      'cin': '09729031',
      'filiere': 'Licence en Informatique et Multimédia (LSIM)',
      'years': [
        {
          'AU': '2026-2027',
          'Niveau': '3',
          'Classe': 'LSIM3',
          'Groupe': '',
          'N° Inscription': '2024666',
          'Statut': 'Nouveau',
          'Inscription': 'Confirmée',
          'Moyenne': '0 (S1)',
          'Crédits': '0',
          'Résultat': 'NC',
        },
        {
          'AU': '2025-2026',
          'Niveau': '2',
          'Classe': 'LSIM2',
          'Groupe': 'C',
          'N° Inscription': '2024666',
          'Statut': 'Nouveau',
          'Inscription': 'Confirmée',
          'Moyenne': '11.13',
          'Crédits': '48',
          'Résultat': 'Admis en session Principale',
        },
        {
          'AU': '2023-2024',
          'Niveau': '1',
          'Classe': 'LSIM1',
          'Groupe': 'C',
          'N° Inscription': '2024666',
          'Statut': 'Nouveau',
          'Inscription': 'Confirmée',
          'Moyenne': '6.83',
          'Crédits': '18',
          'Résultat': 'Redouble',
        },
      ],
    });
  }

  @override
  Future<Schedule> getSchedule({String? week}) async {
    requestedWeeks.add(week);
    return Schedule.fromJson({
      'weekLabel': 'semaine $week',
      'hasSessions': false,
      'rawContentHtml': null,
    });
  }
}

Widget wrap(FakeApiClient api) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      // Skip the login flow: start already authenticated.
      authProvider.overrideWith(() => _AuthedNotifier()),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
  );
}

class _AuthedNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    SharedPreferences.setMockInitialValues({});
    StudentAvatar.debugDisableRemote = true;
  });

  tearDown(() => StudentAvatar.debugDisableRemote = false);

  testWidgets('lands on Emploi, not Notes', (tester) async {
    await tester.pumpWidget(wrap(FakeApiClient()));
    await tester.pump(const Duration(milliseconds: 300));

    // AppBar title reflects the active tab.
    expect(find.text('Votre semaine'), findsOneWidget);
    expect(find.text('Relevés et moyennes'), findsNothing);
  });

  testWidgets('the version footer does not follow the student past login',
      (tester) async {
    await tester.pumpWidget(wrap(FakeApiClient()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(VersionFooter), findsNothing);
  });

  testWidgets('grades request omits au/ss so the server picks the current année',
      (tester) async {
    final api = FakeApiClient();
    await tester.pumpWidget(wrap(api));
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to the Notes tab.
    await tester.tap(find.text('Notes').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.lastAu, isNull, reason: 'first load should defer to the server default');
    expect(api.lastSs, isNull);
  });

  testWidgets('année dropdown labels the year the data actually belongs to',
      (tester) async {
    await tester.pumpWidget(wrap(FakeApiClient()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Notes').last);
    await tester.pump(const Duration(milliseconds: 300));

    // Backend resolved currentAu=12; must not fall back to the first option.
    expect(find.text('2025-2026'), findsOneWidget);
    expect(find.text('2026-2027'), findsNothing);
  });

  testWidgets('changing the année refetches and sends BOTH au and ss', (tester) async {
    final api = FakeApiClient();
    await tester.pumpWidget(wrap(api));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Notes').last);
    await tester.pump(const Duration(milliseconds: 300));
    final callsBefore = api.gradesCallCount;

    // Open the année dropdown and pick a different year.
    await tester.tap(find.text('2025-2026'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('2024-2025').last);
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.gradesCallCount, greaterThan(callsBefore), reason: 'should refetch');
    expect(api.lastAu, '11');
    // ss must be pinned too — the upstream form ignores a lone f_au.
    expect(api.lastSs, isNotNull, reason: 'session must accompany the année');
    expect(api.lastSs, '1');
  });

  testWidgets('week arrows move the schedule forward and back a week', (tester) async {
    final api = FakeApiClient();
    await tester.pumpWidget(wrap(api));
    await tester.pump(const Duration(milliseconds: 300));

    final firstWeek = DateTime.parse('${api.requestedWeeks.first}');

    await tester.tap(find.byTooltip('Semaine suivante'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      DateTime.parse('${api.requestedWeeks.last}').difference(firstWeek).inDays,
      7,
    );

    await tester.tap(find.byTooltip('Semaine précédente'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(DateTime.parse('${api.requestedWeeks.last}'), firstWeek);
  });

  testWidgets('schedule always requests a Monday', (tester) async {
    final api = FakeApiClient();
    await tester.pumpWidget(wrap(api));
    await tester.pump(const Duration(milliseconds: 300));

    expect(DateTime.parse('${api.requestedWeeks.first}').weekday, DateTime.monday);
  });

  testWidgets('profile tab shows identity and every cursus year', (tester) async {
    // Taller surface than the 800x600 default so the lazily-built ListView
    // renders every year rather than only those initially on screen.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(FakeApiClient()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Profil').last);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ahmed Haddaji'), findsOneWidget);
    expect(find.text('AH'), findsOneWidget);
    expect(find.text('09729031'), findsOneWidget);
    expect(find.text('Licence en Informatique et Multimédia (LSIM)'), findsOneWidget);

    // One entry per academic year, newest first.
    expect(find.text('2026-2027'), findsOneWidget);
    expect(find.text('2025-2026'), findsOneWidget);
    expect(find.text('2023-2024'), findsOneWidget);
    expect(find.text('Admis en session Principale'), findsOneWidget);
    expect(find.text('Redouble'), findsOneWidget);
  });

  testWidgets('opening Notes fetches grades exactly once', (tester) async {
    final api = FakeApiClient();
    await tester.pumpWidget(wrap(api));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Notes').last);
    await tester.pump(const Duration(milliseconds: 400));

    // Resolving the année from the response must not trigger a second round
    // trip; the dropdown reads the value rather than re-selecting it.
    expect(api.gradesCallCount, 1);
  });

  testWidgets('failing grades below 10 are flagged in red', (tester) async {
    await tester.pumpWidget(wrap(FakeApiClient()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Notes').last);
    await tester.pump(const Duration(milliseconds: 300));

    // Published matière average 6.5 -> danger colour, shown without a marker.
    final matiereAverage = tester.widget<Text>(find.text('6.50'));
    expect(matiereAverage.style?.color, AppColors.danger);
  });

  testWidgets('derives a missing matière average and marks it an estimate',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(FakeApiClient()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Notes').last);
    await tester.pump(const Duration(milliseconds: 300));

    // Analyse 1 has only its DS (12) posted, so the standing is 12.00 and the
    // "~" prefix plus warning colour flag it as provisional.
    final estimate = tester.widget<Text>(find.text('~12.00'));
    expect(estimate.style?.color, AppColors.warning);

    // The legend explaining the marker appears alongside it.
    expect(find.textContaining('non officielle'), findsOneWidget);
  });
}
