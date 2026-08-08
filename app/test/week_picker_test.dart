import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/providers/schedule_provider.dart';
import 'package:isimg_app/screens/schedule_screen.dart';
import 'package:isimg_app/theme/app_theme.dart';

class RecordingApi implements ApiClient {
  final requestedWeeks = <String?>[];

  @override
  Future<Schedule> getSchedule({String? week}) async {
    requestedWeeks.add(week);
    return Schedule(weekLabel: 'semaine $week', hasSessions: false);
  }

  @override
  Future<Grades> getGrades({String? au, String? ss}) async =>
      Grades.fromJson({'semesters': <dynamic>[]});

  @override
  Future<Profile> getProfile() async => Profile.fromJson({'years': <dynamic>[]});

  @override
  Future<LoginResult> login(String username, String password) async => LoginOk();

  @override
  Future<void> verifyOtp({
    required String session,
    required String token2fa,
    required String code,
  }) async {}
}

class _AuthedNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

Widget wrap(RecordingApi api) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith(() => _AuthedNotifier()),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      // Same localisation as the real app, so the picker's buttons are French.
      locale: const Locale('fr'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
      home: const Scaffold(body: ScheduleScreen()),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the navigator offers a week picker alongside the arrows',
      (tester) async {
    await tester.pumpWidget(wrap(RecordingApi()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Semaine précédente'), findsOneWidget);
    expect(find.byTooltip('Semaine suivante'), findsOneWidget);
    expect(find.byTooltip('Choisir une semaine'), findsOneWidget);
  });

  testWidgets('the current week is labelled as such', (tester) async {
    await tester.pumpWidget(wrap(RecordingApi()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Semaine en cours'), findsOneWidget);

    // Moving away swaps the hint to the way back.
    await tester.tap(find.byTooltip('Semaine suivante'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Semaine en cours'), findsNothing);
    expect(find.text('Appuyez pour revenir à aujourd\'hui'), findsOneWidget);
  });

  testWidgets('the picker opens a calendar and jumps to the chosen week',
      (tester) async {
    final api = RecordingApi();
    await tester.pumpWidget(wrap(api));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Choisir une semaine'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir une semaine'), findsWidgets);

    // Pick a day, then confirm.
    final target = DateTime.now().add(const Duration(days: 2));
    await tester.tap(find.text('${target.day}').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Whatever day was chosen, the request is for that week's Monday.
    final requested = api.requestedWeeks.last;
    expect(requested, formatWeek(mondayOf(target)));
  });

  testWidgets('dismissing the picker leaves the week alone', (tester) async {
    final api = RecordingApi();
    await tester.pumpWidget(wrap(api));
    await tester.pump(const Duration(milliseconds: 300));
    final before = api.requestedWeeks.length;

    await tester.tap(find.byTooltip('Choisir une semaine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(api.requestedWeeks.length, before, reason: 'no refetch on cancel');
  });
}
