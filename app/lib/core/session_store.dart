import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const _sessionKey = 'isimg_session';

  final FlutterSecureStorage _storage;

  /// In-memory copy of the stored session. Secure storage is slow on Android
  /// (Keystore decryption on the platform thread) and every API call reads the
  /// session, so it's read once and then served from memory. All writes go
  /// through this instance, which keeps the copy in sync.
  Future<String?>? _memo;

  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> read() {
    return _memo ??= _readStorage().then((value) => value, onError: (Object _) {
      _memo = null; // Don't remember a failed read.
      return null;
    });
  }

  Future<String?> _readStorage() => _storage.read(key: _sessionKey);

  Future<void> save(String session) async {
    _memo = Future.value(session);
    try {
      await _storage.write(key: _sessionKey, value: session);
    } catch (_) {
    }
  }

  Future<void> clear() async {
    _memo = Future.value(null);
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
