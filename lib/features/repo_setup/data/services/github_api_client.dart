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
}
