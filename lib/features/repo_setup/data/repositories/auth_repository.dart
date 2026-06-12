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

  // The one scope the app can't function without (read access to repos/PRs).
  // `read:org` and `read:project` only gate optional features (org repo
  // discovery, Lead Cockpit), so they degrade gracefully instead of blocking.
  static const _essentialScope = 'repo';
  static const _recommendedScopes = {'read:org', 'read:project'};

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

      // `x-oauth-scopes` is only sent for classic PATs / OAuth tokens.
      // Fine-grained PATs and GitHub App tokens omit it — we can't introspect
      // their permissions, so we trust them (they authenticated). We never
      // reject for *extra* scopes; only a classic token that plainly can't
      // read repos is blocked. Missing optional scopes are logged, not failed.
      final scopeHeader = res.headers.value('x-oauth-scopes');
      if (scopeHeader != null && scopeHeader.trim().isNotEmpty) {
        final granted = scopeHeader.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
        if (!granted.contains(_essentialScope)) {
          return Result.failure(
            "Token can't read repositories — add the '$_essentialScope' scope.",
            StackTrace.current,
          );
        }
        final missingOptional = _recommendedScopes.difference(granted);
        if (missingOptional.isNotEmpty) {
          log('GitHub token missing optional scopes (some features limited): ${missingOptional.join(', ')}');
        }
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
