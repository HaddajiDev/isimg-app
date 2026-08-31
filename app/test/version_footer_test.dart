import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:isimg_app/widgets/version_footer.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'ISIMG',
      packageName: 'io.github.haddajidev.isimg',
      version: '1.0.3',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  testWidgets('shows the real app version once it resolves', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: VersionFooter())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('ISIMG Étudiant · v1.0.3 (4)'), findsOneWidget);
  });

  testWidgets('renders nothing before the version has resolved', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: VersionFooter())),
      ),
    );

    expect(find.byType(Text), findsNothing);
  });
}
