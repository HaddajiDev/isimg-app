import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Credentials {
  final String username;
  final String password;

  const Credentials({required this.username, required this.password});
}

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
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _usernameKey);
      await _storage.delete(key: _passwordKey);
    } catch (_) {
    }
  }
}
