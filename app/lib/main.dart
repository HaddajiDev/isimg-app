import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: IsimgApp()));
}

class IsimgApp extends StatelessWidget {
  const IsimgApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'ISIMG',
      debugShowCheckedModeBanner: false,
      // Dark-only by design; there is no light variant to fall back to.
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authProvider).status;

    return switch (status) {
      AuthStatus.checking => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.unauthenticated || AuthStatus.submitting => const LoginScreen(),
      AuthStatus.otpPending => const OtpScreen(),
      AuthStatus.authenticated => const HomeScreen(),
    };
  }
}
