import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real body api.dicebear.com returns for a student's avatar.
String get avatarSvg => File('test/fixtures/avatar.svg').readAsStringSync();

void main() {
  test('the response really is the animated flavour', () {
    // CSS keyframes plus custom properties: the reason this is worth checking.
    expect(avatarSvg, contains('<style'));
    expect(avatarSvg, contains('@keyframes'));
    expect(avatarSvg, contains('--dbcr-'));
  });

  test('flutter_svg can decode what DiceBear returns', () async {
    // If this throws, the avatar can never render on the device no matter what
    // the network does — the fallback initials would always win.
    Object? failure;
    try {
      await vg.loadPicture(SvgStringLoader(avatarSvg), null);
    } catch (e) {
      failure = e;
    }

    expect(
      failure,
      isNull,
      reason: 'flutter_svg rejected the DiceBear SVG: $failure',
    );
  });
}
