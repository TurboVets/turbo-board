import 'dart:developer';

import 'package:turbo_core/core.dart';

import '../models/github_repo.dart';
import '../models/github_user.dart';
import '../services/github_api_client.dart';

abstract interface class AuthRepository {
  /// Validates [token]; on success returns the authenticated user.
  Future<Result<GithubUser>> validateToken(String token);

  /// Lists every repo the current token can access (paginated).
  Future<Result<List<GithubRepo>>> listAccessibleRepos();
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final GithubApiClient _client;
  // `read:project` is needed for the Lead Cockpit's Projects v2 board query.
  static const _requiredScopes = {'repo', 'read:org', 'read:project'};

  @override
  Future<Result<GithubUser>> validateToken(String token) async {
    try {
      _client.setToken(token);
      final res = await _client.dio.get<Map<String, dynamic>>('/user');

      if (res.statusCode == 401) {
        return Result.failure('Invalid or expired token.', StackTrace.current);
      }
      if (res.statusCode != 200 || res.data == null) {
        return Result.failure('GitHub rejected the token (HTTP ${res.statusCode}).', StackTrace.current);
      }

      final granted = (res.headers.value('x-oauth-scopes') ?? '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      final missing = _requiredScopes.difference(granted);
      if (missing.isNotEmpty) {
        return Result.failure('Token is missing scopes: ${missing.join(', ')}.', StackTrace.current);
      }

      return Result.success(GithubUser.fromJson(res.data!));
    } catch (e, stackTrace) {
      log('validateToken failed', error: e, stackTrace: stackTrace);
      return Result.failure('Could not reach GitHub. Check your connection.', stackTrace);
    }
  }

  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async {
    try {
      final repos = <GithubRepo>[];
      String? path = '/user/repos?affiliation=owner,collaborator,organization_member&per_page=100&sort=pushed';

      while (path != null) {
        final res = await _client.dio.get<List<dynamic>>(path);
        if (res.statusCode != 200 || res.data == null) {
          return Result.failure('Could not load repositories (HTTP ${res.statusCode}).', StackTrace.current);
        }
        repos.addAll(res.data!.map((e) => GithubRepo.fromJson(e as Map<String, dynamic>)));
        path = _nextLink(res.headers.value('link'));
      }

      return Result.success(repos);
    } catch (e, stackTrace) {
      log('listAccessibleRepos failed', error: e, stackTrace: stackTrace);
      return Result.failure('Could not load repositories.', stackTrace);
    }
  }

  /// Extracts the `rel="next"` URL from a GitHub `Link` header, or null.
  static String? _nextLink(String? linkHeader) {
    if (linkHeader == null) return null;
    for (final part in linkHeader.split(',')) {
      final segments = part.split(';');
      if (segments.length < 2) continue;
      if (segments[1].contains('rel="next"')) {
        return segments[0].trim().replaceAll('<', '').replaceAll('>', '');
      }
    }
    return null;
  }
}

/// Offline / test implementation returning canned data.
class MockAuthRepository implements AuthRepository {
  const MockAuthRepository();

  @override
  Future<Result<GithubUser>> validateToken(String token) async =>
      Result.success(const GithubUser(login: 'octocat', avatarUrl: '', name: 'The Octocat'));

  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async => Result.success(const [
    GithubRepo(name: 'platform', nameWithOwner: 'TurboVets/platform', owner: 'TurboVets'),
    GithubRepo(name: 'mobile_recruit', nameWithOwner: 'TurboVets/mobile_recruit', owner: 'TurboVets'),
  ]);
}
