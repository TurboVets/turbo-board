// test/features/repo_setup/data/repositories/auth_repository_test.dart
//
// Test summary:
// - validateToken: 200 + required scopes -> success(user)
// - validateToken: 401 -> failure("Invalid or expired token.")
// - validateToken: classic token with only `repo` (no optional scopes) -> success (tolerant)
// - validateToken: fine-grained token (no x-oauth-scopes header) -> success (can't introspect)
// - validateToken: classic token missing the essential `repo` scope -> failure
// - listAccessibleRepos: follows Link rel="next" across two pages and concatenates
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';
import 'package:turbo_board/features/repo_setup/data/repositories/auth_repository.dart';
import 'package:turbo_board/features/repo_setup/data/services/github_api_client.dart';
import 'package:turbo_core/core.dart';

import 'auth_repository_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio dio;
  late AuthRepositoryImpl repo;

  setUp(() {
    dio = MockDio();
    when(dio.options).thenReturn(BaseOptions());
    repo = AuthRepositoryImpl(GithubApiClient(dio: dio));
  });

  Response<T> resp<T>(T? data, {int status = 200, Map<String, List<String>> headers = const {}}) => Response<T>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: status,
    data: data,
    headers: Headers.fromMap(headers),
  );

  test('validateToken returns the user on 200 with required scopes', () async {
    when(dio.get<Map<String, dynamic>>('/user')).thenAnswer(
      (_) async => resp<Map<String, dynamic>>(
        {'login': 'octocat', 'avatar_url': 'x', 'name': 'Octo'},
        headers: {
          'x-oauth-scopes': ['repo, read:org, read:project'],
        },
      ),
    );

    final result = await repo.validateToken('tok');

    expect(result, isA<ResultSuccess<GithubUser>>());
    expect((result as ResultSuccess<GithubUser>).data.login, 'octocat');
  });

  test('validateToken fails on 401', () async {
    when(dio.get<Map<String, dynamic>>('/user')).thenAnswer((_) async => resp<Map<String, dynamic>>(null, status: 401));

    final result = await repo.validateToken('bad');

    expect(result, isA<ResultFailure<GithubUser>>());
    expect((result as ResultFailure<GithubUser>).message, contains('Invalid or expired'));
  });

  test('validateToken succeeds with only `repo` — optional scopes are tolerated', () async {
    when(dio.get<Map<String, dynamic>>('/user')).thenAnswer(
      (_) async => resp<Map<String, dynamic>>(
        {'login': 'octocat', 'avatar_url': 'x'},
        headers: {
          'x-oauth-scopes': ['repo'],
        },
      ),
    );

    final result = await repo.validateToken('tok');

    expect(result, isA<ResultSuccess<GithubUser>>());
  });

  test('validateToken succeeds for fine-grained tokens (no x-oauth-scopes header)', () async {
    when(
      dio.get<Map<String, dynamic>>('/user'),
    ).thenAnswer((_) async => resp<Map<String, dynamic>>({'login': 'octocat', 'avatar_url': 'x'}));

    final result = await repo.validateToken('github_pat_xxx');

    expect(result, isA<ResultSuccess<GithubUser>>());
  });

  test('validateToken fails when the essential `repo` scope is missing', () async {
    when(dio.get<Map<String, dynamic>>('/user')).thenAnswer(
      (_) async => resp<Map<String, dynamic>>(
        {'login': 'octocat', 'avatar_url': 'x'},
        headers: {
          'x-oauth-scopes': ['read:org, gist'],
        },
      ),
    );

    final result = await repo.validateToken('tok');

    expect(result, isA<ResultFailure<GithubUser>>());
    expect((result as ResultFailure<GithubUser>).message, contains('repo'));
  });

  test('listAccessibleRepos follows Link pagination', () async {
    const firstPath = '/user/repos?affiliation=owner,collaborator,organization_member&per_page=100&sort=pushed';
    when(dio.get<List<dynamic>>(firstPath)).thenAnswer(
      (_) async => resp<List<dynamic>>(
        [
          {
            'name': 'a',
            'full_name': 'o/a',
            'owner': {'login': 'o'},
            'private': false,
          },
        ],
        headers: {
          'link': ['<https://api.github.com/user/repos?page=2>; rel="next"'],
        },
      ),
    );
    when(dio.get<List<dynamic>>('https://api.github.com/user/repos?page=2')).thenAnswer(
      (_) async => resp<List<dynamic>>([
        {
          'name': 'b',
          'full_name': 'o/b',
          'owner': {'login': 'o'},
          'private': false,
        },
      ]),
    );

    final result = await repo.listAccessibleRepos();

    expect(result, isA<ResultSuccess<List<GithubRepo>>>());
    final repos = (result as ResultSuccess<List<GithubRepo>>).data;
    expect(repos.map((r) => r.name), ['a', 'b']);
  });
}
