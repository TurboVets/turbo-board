import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's Anthropic API key (BYOK). Never logged.
abstract interface class ApiKeyStore {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> delete();
}

/// Backed by flutter_secure_storage (Keychain / Keystore / WebCrypto).
///
/// Web caveat: on web the key is protected by WebCrypto and does NOT survive a
/// browser-data clear — the user re-enters it after such a clear.
class SecureApiKeyStore implements ApiKeyStore {
  const SecureApiKeyStore([this._storage = const FlutterSecureStorage()]);

  static const _key = 'anthropic_api_key';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String key) => _storage.write(key: _key, value: key);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// In-memory fake for tests and offline development.
class InMemoryApiKeyStore implements ApiKeyStore {
  InMemoryApiKeyStore([this._key]);

  String? _key;

  @override
  Future<String?> read() async => _key;

  @override
  Future<void> write(String key) async => _key = key;

  @override
  Future<void> delete() async => _key = null;
}
