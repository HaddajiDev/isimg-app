import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/screens/grades_screen.dart';
import 'package:isimg_app/theme/app_theme.dart';
import 'package:isimg_app/widgets/student_avatar.dart';

/// Mirrors the shape of the 2026-2027 stand-in bulletin: notes posted, no
/// averages published, a single semester.
class MidYearApi implements ApiClient {
  @override
  Future<Grades> getGrades({String? au, String? ss}) async {
    return Grades.fromJson({
      'nom': 'Haddaji Ahmed',
      'niveau': '3',
      'moyenneGenerale': null,
      'credits': null,
      'rang': null,
      'currentAu': '13',
      'currentSs': '1',
      'annees': [
        {'code': '13', 'label': '2026-2027', 'selected': false},
      ],
      'sessions': [
        {'code': '1', 'label': 'Principale', 'selected': false},
      ],
      'semesters': [
        {
          'semestre': '1',
          'unites': [
            {
              'libelle': 'Uef410 : génie logiciel',
              'coefficient': 3,
              'credits': 6,
              'moyenne': null,
              'matieres': [
                {
                  'libelle': 'Qualité du logiciel',
                  'regime': 'RM',
                  'coefficient': 1.5,
                  'credits': 3,
                  'moyenne': null,
                  'epreuves': [
                    {'libelle': 'DS (0.3)', 'poids': 0.3, 'note': 10},
                    {'libelle': 'Ex (0.7)', 'poids': 0.7, 'note': null},
                  ],
                },
              ],
            },
          ],
        },
      ],
    });
  }

  @override
  Future<Profile> getProfile() async =>
      Profile.fromJson({'years': <dynamic>[]});

  @override
  Future<Schedule> getSchedule({String? week}) async =>
      Schedule.fromJson({'hasSessions': false});

  @override
  Future<LoginResult> login(String username, String password) async => LoginOk();

  @override
  Future<void> verifyOtp({required String session, required String token2fa, required String code}) async {}
}

class _AuthedNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

Widget wrap() {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(MidYearApi()),
      authProvider.overrideWith(() => _AuthedNotifier()),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(body: GradesScreen()),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentAvatar.debugDisableRemote = true;
  });

  tearDown(() => StudentAvatar.debugDisableRemote = false);

  testWidgets('shows a partial standing before any manual note', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 400));

    // Only the DS (10) is graded, so the standing is 10.00 and provisional.
    expect(find.text('~10.00'), findsWidgets);
    expect(find.text('–'), findsOneWidget);
  });

  testWidgets('entering a note updates the average and marks it simulated',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 400));

    // Tap the ungraded Ex chip.
    await tester.tap(find.text('Ex (0.7)'));
    await tester.pumpAndSettle();
    expect(find.text('Note provisoire'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '15');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // 10*0.3 + 15*0.7 = 13.50, now a full simulation.
    final chip = tester.widget<Text>(find.text('~13.50').first);
    expect(chip.style?.color, AppColors.purple);

    // The banner reports the active projection.
    expect(find.textContaining('1 note provisoire'), findsOneWidget);
  });

  testWidgets('a manual note can be deleted again', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Ex (0.7)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '15');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('~13.50'), findsWidgets);

    // Reopen and delete.
    await tester.tap(find.text('Ex (0.7)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer cette note'));
    await tester.pumpAndSettle();

    expect(find.text('~13.50'), findsNothing);
    expect(find.text('~10.00'), findsWidgets);
    expect(find.textContaining('note provisoire'), findsNothing);
  });

  testWidgets('an official note offers no editing affordance', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 400));

    // The graded DS must not be tappable, so no sheet appears.
    await tester.tap(find.text('DS (0.3)'));
    await tester.pumpAndSettle();
    expect(find.text('Note provisoire'), findsNothing);
  });

  testWidgets('rejects a note outside 0-20', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Ex (0.7)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '25');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Sheet stays open with an explanation.
    expect(find.textContaining('entre 0 et 20'), findsOneWidget);
  });
}
