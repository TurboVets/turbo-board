import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the GitHub personal access token. Never logged.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

/// Backed by flutter_secure_storage (Keychain / Keystore / WebCrypto).
///
/// Web caveat: on web, keys are protected by WebCrypto and do NOT survive a
/// browser-data clear — the user re-enters the token after such a clear.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  static const _key = 'github_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// In-memory fake for tests and offline development.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> delete() async => _token = null;
}
