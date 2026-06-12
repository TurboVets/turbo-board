import 'package:dio/dio.dart';

/// A GitHub-scoped Dio instance.
///
/// We do NOT reuse turbo_core's `DioClient.I`: it is bound to the TurboVets
/// backend base URL and injects Cloudflare-Access headers that must never be
/// sent to api.github.com.
class GithubApiClient {
  GithubApiClient({Dio? dio, String? token}) : dio = dio ?? _build() {
    if (token != null) setToken(token);
  }

  final Dio dio;

  static Dio _build() => Dio(
    BaseOptions(
      baseUrl: 'https://api.github.com',
      headers: {'Accept': 'application/vnd.github+json'},
      // GitHub returns 401/403/422 we want to inspect, not throw on.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  /// Sets (or clears) the bearer token used for every request.
  void setToken(String? token) {
    if (token == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  /// POSTs a GraphQL [query] with [variables] to GitHub's GraphQL endpoint and
  /// returns the top-level `data` map. Throws on a non-200 status or when the
  /// response carries a non-empty top-level `errors` array.
  Future<Map<String, dynamic>> graphql(String query, Map<String, dynamic> variables) async {
    final res = await dio.post<Map<String, dynamic>>('/graphql', data: {'query': query, 'variables': variables});
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('GitHub GraphQL request failed (HTTP ${res.statusCode}).');
    }
    final errors = res.data!['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final message = first is Map ? (first['message']?.toString() ?? 'GraphQL error') : 'GraphQL error';
      throw Exception(message);
    }
    return (res.data!['data'] as Map<String, dynamic>?) ?? const {};
  }
}
