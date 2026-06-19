import 'ai_provider_kind.dart';

/// A provider-agnostic single-turn chat client (BYOK).
///
/// Implementations talk directly to their provider's API from Dart; the key
/// lives only in flutter_secure_storage and is injected via [setKey]. The
/// surface matches what [AiRepository] needs — nothing more.
abstract interface class LlmClient {
  /// Which provider this client targets.
  AiProvider get provider;

  /// Sets (or clears, when null) the auth credential used for every request.
  void setKey(String? apiKey);

  /// Sends a single user message and returns the concatenated text response.
  /// Throws on a non-success status.
  Future<String> complete({required String prompt, int maxTokens = 512});

  /// Cheap validity check: a 1-token request. true → valid, false → rejected
  /// (401). Throws when validity could not be determined.
  Future<bool> validateKey();
}
