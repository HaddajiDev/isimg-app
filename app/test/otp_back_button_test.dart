import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isimg_app/core/api_client.dart';
import 'package:isimg_app/core/credential_store.dart';
import 'package:isimg_app/models/grades.dart';
import 'package:isimg_app/models/profile.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/providers/api_provider.dart';
import 'package:isimg_app/providers/auth_provider.dart';
import 'package:isimg_app/screens/otp_screen.dart';
import 'package:isimg_app/theme/app_theme.dart';

class _OtpApi implements ApiClient {
  @override
  Future<LoginResult> login(String username, String password) async =>
      LoginOtpRequired(session: 'sess', token2fa: 'tok');

  @override
  Future<void> verifyOtp({required String session, required String token2fa, required String code}) async {}

  @override
  Future<Grades> getGrades({String? au, String? ss}) async => Grades.fromJson({'semesters': <dynamic>[]});

  @override
  Future<Profile> getProfile() async => Profile.fromJson({'years': <dynamic>[]});

  @override
  Future<Schedule> getSchedule({String? week}) async => Schedule.fromJson({'hasSessions': false});
}

class _RecordingCredentialStore extends CredentialStore {
  int clearCount = 0;

  @override
  Future<Credentials?> read() async => null;

  @override
  Future<void> save(Credentials credentials) async {}

  @override
  Future<void> clear() async => clearCount++;
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
  });

  testWidgets(
    'the hardware/gesture back button abandons the pending login, same as the arrow icon',
    (tester) async {
      final credentials = _RecordingCredentialStore();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(_OtpApi()),
          credentialStoreProvider.overrideWithValue(credentials),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).login('2024666', 'pw');
      expect(container.read(authProvider).status, AuthStatus.otpPending);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: buildAppTheme(), home: const OtpScreen()),
        ),
      );

      // AuthGate itself never pushes a route for OtpScreen, but MaterialApp
      // still wraps its `home` in one route on its own root Navigator. A real
      // back press asks that Navigator to pop, and PopScope intercepts the
      // attempt before it can happen — so driving the Navigator is what
      // actually exercises the same path a physical/gesture back press takes.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pump();

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(credentials.clearCount, greaterThan(0));
    },
  );
}
