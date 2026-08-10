import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/core/grades_cache.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/screens/grades_screen.dart';
import 'package:isimg_app/theme/app_theme.dart';
import 'package:isimg_app/widgets/student_avatar.dart';

/// Never resolves — stands in for a slow network so the screen is stuck on
/// [gradesProvider]'s loading state for the whole test, which is exactly the
/// window the cache-peek placeholder is meant to fill.
class _StuckApi implements ApiClient {
  @override
  Future<Grades> getGrades({String? au, String? ss}) => Completer<Grades>().future;

  @override
  Future<Profile> getProfile() async => Profile.fromJson({'years': <dynamic>[]});

  @override
  Future<Schedule> getSchedule({String? week}) async => Schedule(hasSessions: false);

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

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    SharedPreferences.setMockInitialValues({});
    StudentAvatar.debugDisableRemote = true;
  });

  tearDown(() => StudentAvatar.debugDisableRemote = false);

  testWidgets(
    'a cached relevé shows immediately while the live fetch is still stuck loading',
    (tester) async {
      await GradesCache().save(
        '_default',
        '_default',
        Grades.fromJson({'nom': 'Étudiant Cache', 'semesters': <dynamic>[]}),
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(_StuckApi()),
          authProvider.overrideWith(() => _AuthedNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(body: GradesScreen()),
          ),
        ),
      );
      // Long enough for the cache read (local, fast) to resolve, but the
      // network call never will — proving this isn't just an early frame.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Étudiant Cache'), findsOneWidget);
      // The thin top progress bar, not the full-page skeleton, marks this as
      // "seeded from cache, still refreshing" rather than "fully loaded".
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'falls back to the skeleton when there is nothing cached to seed with',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(_StuckApi()),
          authProvider.overrideWith(() => _AuthedNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(body: GradesScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Étudiant Cache'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
}
