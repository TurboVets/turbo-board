import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_provider_kind.dart';

/// Persists each provider's BYOK key and which provider is active. Never logged.
abstract interface class ApiKeyStore {
  Future<String?> read(AiProvider provider);
  Future<void> write(AiProvider provider, String key);
  Future<void> delete(AiProvider provider);
  Future<AiProvider?> readActiveProvider();
  Future<void> writeActiveProvider(AiProvider provider);
}

/// Backed by flutter_secure_storage (Keychain / Keystore / WebCrypto).
///
/// Web caveat: on web the key is protected by WebCrypto and does NOT survive a
/// browser-data clear — the user re-enters it after such a clear.
class SecureApiKeyStore implements ApiKeyStore {
  const SecureApiKeyStore([this._storage = const FlutterSecureStorage()]);

  /// Pre-multi-provider key location; migrated to [AiProvider.anthropic.storageKey].
  static const _legacyAnthropicKey = 'anthropic_api_key';
  static const _activeKey = 'llm_active_provider';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(AiProvider provider) async {
    final value = await _storage.read(key: provider.storageKey);
    if (value != null) return value;
    // One-time migration of the legacy single-key storage.
    if (provider == AiProvider.anthropic) {
      final legacy = await _storage.read(key: _legacyAnthropicKey);
      if (legacy != null && legacy.isNotEmpty) {
        await _storage.write(key: provider.storageKey, value: legacy);
        await _storage.delete(key: _legacyAnthropicKey);
        return legacy;
      }
    }
    return null;
  }

  @override
  Future<void> write(AiProvider provider, String key) => _storage.write(key: provider.storageKey, value: key);

  @override
  Future<void> delete(AiProvider provider) => _storage.delete(key: provider.storageKey);

  @override
  Future<AiProvider?> readActiveProvider() async {
    final name = await _storage.read(key: _activeKey);
    if (name == null) return null;
    for (final p in AiProvider.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  @override
  Future<void> writeActiveProvider(AiProvider provider) => _storage.write(key: _activeKey, value: provider.name);
}

/// In-memory fake for tests and offline development.
class InMemoryApiKeyStore implements ApiKeyStore {
  InMemoryApiKeyStore({Map<AiProvider, String>? keys, AiProvider? active}) : _keys = {...?keys}, _active = active;

  final Map<AiProvider, String> _keys;
  AiProvider? _active;

  @override
  Future<String?> read(AiProvider provider) async => _keys[provider];

  @override
  Future<void> write(AiProvider provider, String key) async => _keys[provider] = key;

  @override
  Future<void> delete(AiProvider provider) async => _keys.remove(provider);

  @override
  Future<AiProvider?> readActiveProvider() async => _active;

  @override
  Future<void> writeActiveProvider(AiProvider provider) async => _active = provider;
}
