import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/core/session_store.dart';

String encodeJar(List<Map<String, dynamic>> cookies) =>
    base64Encode(utf8.encode(jsonEncode({'cookies': cookies})));

void main() {
  group('trustedDeviceOf', () {
    test('finds the device token among the other cookies', () {
      final session = encodeJar([
        {'key': 'cookiesession1', 'value': 'ABC'},
        {'key': 'trusted_device', 'value': 'DEVICE-TOKEN'},
        {'key': 'iDzfG79', 'value': 'XYZ'},
      ]);

      expect(SessionStore.trustedDeviceOf(session), 'DEVICE-TOKEN');
    });

    test('returns null when the site has issued none', () {
      final session = encodeJar([
        {'key': 'cookiesession1', 'value': 'ABC'},
      ]);

      expect(SessionStore.trustedDeviceOf(session), isNull);
    });

    test('returns null for a missing or unreadable session', () {
      // A corrupt session must degrade to a normal 2FA login, not throw and
      // take the login screen down with it.
      expect(SessionStore.trustedDeviceOf(null), isNull);
      expect(SessionStore.trustedDeviceOf(''), isNull);
      expect(SessionStore.trustedDeviceOf('not base64 !!'), isNull);
      expect(SessionStore.trustedDeviceOf(base64Encode(utf8.encode('{}'))), isNull);
      expect(
        SessionStore.trustedDeviceOf(base64Encode(utf8.encode('{"cookies":"nope"}'))),
        isNull,
      );
    });

    test('tolerates cookie entries that are not shaped as expected', () {
      final session = base64Encode(
        utf8.encode(jsonEncode({
          'cookies': [
            'a bare string',
            {'novalue': true},
            {'key': 'trusted_device', 'value': 'FOUND'},
          ]
        })),
      );

      expect(SessionStore.trustedDeviceOf(session), 'FOUND');
    });
  });
}
