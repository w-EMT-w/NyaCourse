import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedCredentials {
  const SavedCredentials({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;
}

class CredentialStore {
  const CredentialStore();

  static const _storage = FlutterSecureStorage();
  static const _usernameKey = 'gdut_username';
  static const _passwordKey = 'gdut_password';

  Future<SavedCredentials?> read() async {
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return SavedCredentials(username: username, password: password);
  }

  Future<void> save({
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }
}
