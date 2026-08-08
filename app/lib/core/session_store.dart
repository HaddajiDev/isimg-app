import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the ISIMG session — the cookie jar — on this device.
///
/// The backend keeps no session state of its own: it receives this blob with
/// every request and hands back the updated version, which we store again. That
/// is what lets the site rotate its anti-replay cookie without logging us out.
class SessionStore {
  static const _sessionKey = 'isimg_session';

  final FlutterSecureStorage _storage;

  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> read() async {
    try {
      return await _storage.read(key: _sessionKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String session) async {
    try {
      await _storage.write(key: _sessionKey, value: session);
    } catch (_) {
      // Nothing persisted; the session lives on in memory for this run only.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {
      // Already unreadable, so there is nothing to remove.
    }
  }

  /// Reads the site's "remember this device" cookie out of a stored session.
  ///
  /// Replaying it at the next login is what stops ISIMG emailing a fresh code
  /// every time a session lapses.
  static String? trustedDeviceOf(String? session) {
    if (session == null) return null;
    try {
      final jar = jsonDecode(utf8.decode(base64Decode(session)));
      final cookies = (jar as Map<String, dynamic>)['cookies'] as List<dynamic>?;
      if (cookies == null) return null;
      for (final cookie in cookies) {
        if (cookie is Map<String, dynamic> && cookie['key'] == 'trusted_device') {
          return cookie['value'] as String?;
        }
      }
    } catch (_) {
      // Malformed session: fall back to a full login with 2FA.
    }
    return null;
  }
}
