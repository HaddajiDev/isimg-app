import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:isimg_app/main.dart';
import 'package:isimg_app/widgets/version_footer.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
    PackageInfo.setMockInitialValues(
      appName: 'ISIMG',
      packageName: 'io.github.haddajidev.isimg',
      version: '1.0.3',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  testWidgets('shows the login screen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: IsimgApp()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('the version footer lives only on the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: IsimgApp()));
    await tester.pump(const Duration(milliseconds: 500));
    // Auth settling onto the login screen and this footer's own
    // FutureProvider are two separate async chains — give the second one a
    // beat too rather than assuming one pump covers both.
    await tester.pump(const Duration(milliseconds: 100));

    // Still on the login screen (no credentials, nothing to sign in with).
    expect(find.byType(VersionFooter), findsOneWidget);
    expect(find.text('ISIMG Étudiant · v1.0.3 (4)'), findsOneWidget);
  });
}
