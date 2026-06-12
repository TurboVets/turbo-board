import 'package:dio/dio.dart';

/// An Anthropic-scoped Dio instance for the Messages API (BYOK).
///
/// Like GithubApiClient, we do NOT reuse turbo_core's `DioClient.I`: that is
/// bound to the TurboVets backend and injects Cloudflare-Access headers that
/// must never be sent to api.anthropic.com.
///
/// The model is fixed to `claude-haiku-4-5` (per docs/V1-SCOPE.md — cheap enough
/// for BYOK). The key lives only in flutter_secure_storage; never logged.
class AnthropicApiClient {
  AnthropicApiClient({Dio? dio, String? apiKey}) : dio = dio ?? _build() {
    if (apiKey != null) setKey(apiKey);
  }

  final Dio dio;

  static const String model = 'claude-haiku-4-5';
  static const String _version = '2023-06-01';

  static Dio _build() => Dio(
    BaseOptions(
      baseUrl: 'https://api.anthropic.com',
      headers: {'anthropic-version': _version, 'content-type': 'application/json'},
      // Inspect 400/401/429 rather than throw on them.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  /// Sets (or clears) the `x-api-key` header used for every request.
  void setKey(String? apiKey) {
    if (apiKey == null) {
      dio.options.headers.remove('x-api-key');
    } else {
      dio.options.headers['x-api-key'] = apiKey;
    }
  }

  /// Sends a single-turn Messages request and returns the concatenated text of
  /// the response content blocks. Throws on a non-200 status.
  Future<String> complete({required String prompt, int maxTokens = 512}) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/messages',
      data: {
        'model': model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    );
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('Anthropic request failed (HTTP ${res.statusCode}).');
    }
    final blocks = (res.data!['content'] as List<dynamic>?) ?? const [];
    return blocks
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text']?.toString() ?? '')
        .join();
  }

  /// Cheap validity check: a 1-token ping. 200 → valid, 401 → invalid key.
  Future<bool> validateKey() async {
    final res = await dio.post<Map<String, dynamic>>(
      '/v1/messages',
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
    throw Exception('Could not validate key (HTTP ${res.statusCode}).');
  }
}
