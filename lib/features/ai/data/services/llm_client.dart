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

/// A failed LLM request that carries the provider's own error text so it can be
/// surfaced to the user (e.g. "You exceeded your current quota...").
///
/// [message] is the clean provider message safe for display; [statusCode] is
/// the HTTP status; [code] is the provider error code/type (e.g.
/// `insufficient_quota`). The key is never part of a provider error body, so
/// this is safe to surface and log.
class LlmException implements Exception {
  const LlmException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    final tag = code == null || code!.isEmpty ? '' : ' [$code]';
    return 'LlmException$status$tag: $message';
  }
}
