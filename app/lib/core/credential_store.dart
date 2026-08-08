import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Credentials {
  final String username;
  final String password;

  const Credentials({required this.username, required this.password});
}

/// Keeps the student's ISIMG credentials on their own device so an expired
/// session can be renewed without them typing anything.
///
/// On Android the plugin's defaults already encrypt at rest — AES-GCM with the
/// key wrapped by RSA-OAEP in the Keystore — which is what makes storing a
/// password acceptable at all. The credentials never leave the device except as
/// a normal login request to our own backend, which does not persist them.
class CredentialStore {
  static const _usernameKey = 'isimg_username';
  static const _passwordKey = 'isimg_password';

  final FlutterSecureStorage _storage;

  CredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<bool> hasCredentials() async => (await read()) != null;

  Future<Credentials?> read() async {
    try {
      final username = await _storage.read(key: _usernameKey);
      final password = await _storage.read(key: _passwordKey);
      if (username == null || password == null) return null;
      return Credentials(username: username, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Credentials credentials) async {
    try {
      await _storage.write(key: _usernameKey, value: credentials.username);
      await _storage.write(key: _passwordKey, value: credentials.password);
    } catch (_) {
      // Storage unavailable: auto-login simply won't be offered.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _usernameKey);
      await _storage.delete(key: _passwordKey);
    } catch (_) {
      // Nothing further to do; the credentials were already unreadable.
    }
  }
}
