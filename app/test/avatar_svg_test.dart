import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

String get avatarSvg => File('test/fixtures/avatar.svg').readAsStringSync();

void main() {
  test('the response really is the animated flavour', () {
    expect(avatarSvg, contains('<style'));
    expect(avatarSvg, contains('@keyframes'));
    expect(avatarSvg, contains('--dbcr-'));
  });

  test('flutter_svg can decode what DiceBear returns', () async {
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
