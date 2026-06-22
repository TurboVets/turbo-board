import 'package:dio/dio.dart';

import 'ai_provider_kind.dart';
import 'llm_client.dart';

/// An OpenAI-scoped Dio instance for the Chat Completions API (BYOK).
///
/// Like [AnthropicApiClient], it does NOT reuse turbo_core's `DioClient.I`
/// (that is bound to the TurboVets backend). The model is fixed to
/// `gpt-4o-mini` — cheap enough for BYOK. The key lives only in
/// flutter_secure_storage and is sent as `Authorization: Bearer`; never logged.
class OpenAiApiClient implements LlmClient {
  OpenAiApiClient({Dio? dio, String? apiKey}) : dio = dio ?? _build() {
    if (apiKey != null) setKey(apiKey);
  }

  final Dio dio;

  @override
  AiProvider get provider => AiProvider.openai;

  static const String model = 'gpt-4o-mini';

  static Dio _build() => Dio(
    BaseOptions(
      baseUrl: 'https://api.openai.com',
      headers: {'content-type': 'application/json'},
      // Inspect 400/401/429 rather than throw on them.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  @override
  void setKey(String? apiKey) {
    if (apiKey == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $apiKey';
    }
  }

  @override
  Future<String> complete({required String prompt, int maxTokens = 512}) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/chat/completions',
      data: {
        'model': model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    );
    if (res.statusCode != 200 || res.data == null) {
      throw _failure(res.statusCode, res.data);
    }
    final choices = (res.data!['choices'] as List<dynamic>?) ?? const [];
    if (choices.isEmpty) return '';
    final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
    return message?['content']?.toString() ?? '';
  }

  @override
  Future<bool> validateKey() async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/chat/completions',
      data: {
        'model': model,
        'max_tokens': 1,
        'messages': [
          {'role': 'user', 'content': 'ping'},
        ],
      },
    );
    if (res.statusCode == 200) return true;
    if (res.statusCode == 401) return false;
    throw _failure(res.statusCode, res.data);
  }

  /// Builds an [LlmException] from OpenAI's `{"error": {message, type, code}}`
  /// body, preserving the provider's own message (e.g. "You exceeded your
  /// current quota...") so it can be shown to the user. Falls back to a generic
  /// message when no body is present. The key is never in the error body.
  static LlmException _failure(int? statusCode, Map<String, dynamic>? data) {
    final error = data?['error'];
    final message = (error is Map<String, dynamic> ? error['message']?.toString() : null);
    final code = (error is Map<String, dynamic> ? (error['code'] ?? error['type'])?.toString() : null);
    return LlmException(
      message == null || message.isEmpty ? 'OpenAI request failed (HTTP $statusCode).' : message,
      statusCode: statusCode,
      code: code,
    );
  }
}
