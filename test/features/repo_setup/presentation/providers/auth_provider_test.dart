// test/features/repo_setup/presentation/providers/auth_provider_test.dart
//
// Test summary:
// - boot with no stored token -> Unauthenticated
// - boot with a stored valid token -> Authenticated
// - submitToken success -> Authenticated + token written
// - submitToken failure -> AuthError with message
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';
import 'package:turbo_board/features/repo_setup/data/repositories/auth_repository.dart';
import 'package:turbo_board/features/repo_setup/data/services/token_store.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/auth_provider.dart';
import 'package:turbo_core/core.dart';

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo({this.user, this.failMessage});
  final GithubUser? user;
  final String? failMessage;

  @override
  Future<Result<GithubUser>> validateToken(String token) async =>
      failMessage != null ? Result.failure(failMessage!, StackTrace.current) : Result.success(user!);

  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async => Result.success(const []);
}

ProviderContainer makeContainer({required AuthRepository repo, TokenStore? store}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      tokenStoreProvider.overrideWithValue(store ?? InMemoryTokenStore()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

const _user = GithubUser(login: 'octocat', avatarUrl: '', name: 'Octo');

void main() {
  test('boot with no token resolves to unauthenticated', () async {
    final container = makeContainer(repo: _FakeAuthRepo(user: _user));
    container.read(authStateProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
  });

  test('boot with a stored token resolves to authenticated', () async {
    final container = makeContainer(
      repo: _FakeAuthRepo(user: _user),
      store: InMemoryTokenStore('tok'),
    );
    container.read(authStateProvider);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(authStateProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.login, 'octocat');
  });

  test('submitToken success authenticates and writes the token', () async {
    final store = InMemoryTokenStore();
    final container = makeContainer(
      repo: _FakeAuthRepo(user: _user),
      store: store,
    );
    await container.read(authStateProvider.notifier).submitToken('tok');

    expect(container.read(authStateProvider), isA<AuthAuthenticated>());
    expect(await store.read(), 'tok');
  });

  test('submitToken failure surfaces an error message', () async {
    final container = makeContainer(repo: _FakeAuthRepo(failMessage: 'Invalid or expired token.'));
    await container.read(authStateProvider.notifier).submitToken('bad');

    final state = container.read(authStateProvider);
    expect(state, isA<AuthError>());
    expect((state as AuthError).message, 'Invalid or expired token.');
  });
}
