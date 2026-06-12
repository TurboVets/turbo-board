import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../data/models/github_repo.dart';
import '../../data/models/github_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/github_api_client.dart';
import '../../data/services/token_store.dart';

part 'auth_provider.freezed.dart';
part 'auth_provider.g.dart';

@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.validating() = AuthValidating;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.authenticated(GithubUser user) = AuthAuthenticated;
  const factory AuthState.error(String message) = AuthError;
}

@Riverpod(keepAlive: true)
TokenStore tokenStore(Ref ref) => const SecureTokenStore();

@Riverpod(keepAlive: true)
GithubApiClient githubApiClient(Ref ref) => GithubApiClient();

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepositoryImpl(ref.watch(githubApiClientProvider));

@Riverpod(keepAlive: true)
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AuthState build() {
    _init();
    return const AuthState.validating();
  }

  Future<void> _init() async {
    final token = await ref.read(tokenStoreProvider).read();
    if (token == null) {
      state = const AuthState.unauthenticated();
      return;
    }
    ref.read(githubApiClientProvider).setToken(token);
    final result = await ref.read(authRepositoryProvider).validateToken(token);
    state = switch (result) {
      ResultSuccess(:final data) => AuthState.authenticated(data),
      ResultFailure() => const AuthState.unauthenticated(),
    };
  }

  /// Validates and, on success, persists the token and sets authenticated.
  Future<void> submitToken(String token) async {
    state = const AuthState.validating();
    final result = await ref.read(authRepositoryProvider).validateToken(token);
    switch (result) {
      case ResultSuccess(:final data):
        await ref.read(tokenStoreProvider).write(token);
        ref.read(githubApiClientProvider).setToken(token);
        state = AuthState.authenticated(data);
      case ResultFailure(:final message):
        state = AuthState.error(message);
    }
  }

  Future<void> signOut() async {
    await ref.read(tokenStoreProvider).delete();
    ref.read(githubApiClientProvider).setToken(null);
    state = const AuthState.unauthenticated();
  }
}

/// The stored GitHub token (raw) for the Settings PAT row. Re-reads when auth
/// state changes (e.g. after a PAT change). Mask before displaying.
@riverpod
Future<String?> githubToken(Ref ref) async {
  ref.watch(authStateProvider); // refresh after a PAT change / sign-out
  return ref.watch(tokenStoreProvider).read();
}

@riverpod
Future<List<GithubRepo>> accessibleRepos(Ref ref) async {
  final result = await ref.watch(authRepositoryProvider).listAccessibleRepos();
  return switch (result) {
    ResultSuccess(:final data) => data,
    ResultFailure(:final message) => throw Exception(message),
  };
}
