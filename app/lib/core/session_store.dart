import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {
    }
  }

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
    }
    return null;
  }
}
