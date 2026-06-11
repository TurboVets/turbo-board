# Auth + Repo Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** First-run gate that lets a user paste a GitHub PAT, validates it, lets them pick which repos to watch, and routes them to the PR board — with the token in secure storage and watched repos in shared_preferences.

**Architecture:** New `repo_setup` feature under `lib/features/repo_setup/` with the standard data/presentation split. A dedicated GitHub-scoped `Dio` instance (base `https://api.github.com`, bearer-token interceptor) lives in the data layer — we deliberately do NOT reuse turbo_core's `DioClient.I` singleton because it is bound to the TurboVets backend base URL and injects Cloudflare-Access headers we must not send to GitHub. Errors are caught in the repository layer and surfaced upward as turbo_core `Result<T>`. Riverpod (codegen) holds auth + watched-repo state; go_router redirects on auth state.

**Tech Stack:** Flutter, Riverpod (codegen) + flutter_hooks, Freezed, json_serializable, go_router, dio, flutter_secure_storage, shared_preferences, turbo_ui (Tether components), mockito (test).

---

## Reference (read before starting)

- Spec: `docs/superpowers/specs/2026-06-11-auth-repo-setup-design.md`
- Design: `design/mockup.html` (auth card lines ~273–294), `design/README.md` (Tether tokens)
- Existing patterns to mirror:
  - `lib/features/pr_inbox/data/repositories/pr_inbox_repository.dart` (interface + Mock impl + `Result` + `log` on catch)
  - `lib/features/pr_inbox/presentation/providers/pr_inbox_provider.dart` (`@Riverpod(keepAlive:true)` repo provider + `@riverpod` future)
  - `lib/shared/router/app_router.dart` (router provider)
- turbo_core `Result<T>`: sealed; `Result.success(T data)` → `ResultSuccess(data)`; `Result.failure(String message, StackTrace stackTrace)` → `ResultFailure(message, stackTrace)`. Pattern-match with `switch`.
- After any model/provider change: `dart run build_runner build -d`.

## File structure

```
lib/features/repo_setup/
├── data/
│   ├── models/
│   │   ├── github_user.dart          # Freezed: login, avatarUrl, name?
│   │   └── github_repo.dart          # Freezed: owner, name, nameWithOwner, description?, isPrivate, pushedAt?
│   ├── services/
│   │   ├── github_api_client.dart    # dedicated Dio for api.github.com + bearer interceptor
│   │   └── token_store.dart          # TokenStore interface + SecureTokenStore + InMemoryTokenStore
│   └── repositories/
│       └── auth_repository.dart      # interface + AuthRepositoryImpl + MockAuthRepository
└── presentation/
    ├── providers/
    │   ├── auth_provider.dart        # AuthState, AuthStateNotifier, authRepository, githubApiClient, tokenStore, accessibleRepos
    │   └── watched_repos_provider.dart # WatchedReposNotifier (shared_preferences)
    └── view/
        ├── setup_screen.dart         # 2-step wizard (HookConsumerWidget)
        └── widgets/
            ├── auth_step_indicator.dart
            └── repo_pick_list.dart

test/features/repo_setup/
├── data/
│   ├── models/github_user_test.dart
│   ├── models/github_repo_test.dart
│   └── repositories/auth_repository_test.dart
└── presentation/
    ├── providers/auth_provider_test.dart
    ├── providers/watched_repos_provider_test.dart
    └── view/setup_screen_test.dart
```

---

### Task 1: GithubUser model

**Files:**
- Create: `lib/features/repo_setup/data/models/github_user.dart`
- Test: `test/features/repo_setup/data/models/github_user_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/repo_setup/data/models/github_user_test.dart
//
// Test summary:
// - GithubUser.fromJson maps GitHub /user payload (login, avatar_url, name).
// - name is null when absent.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';

void main() {
  test('fromJson maps login, avatarUrl and name', () {
    final user = GithubUser.fromJson(const {
      'login': 'octocat',
      'avatar_url': 'https://example.com/a.png',
      'name': 'The Octocat',
    });

    expect(user.login, 'octocat');
    expect(user.avatarUrl, 'https://example.com/a.png');
    expect(user.name, 'The Octocat');
  });

  test('fromJson tolerates a missing name', () {
    final user = GithubUser.fromJson(const {
      'login': 'octocat',
      'avatar_url': 'https://example.com/a.png',
    });

    expect(user.name, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/repo_setup/data/models/github_user_test.dart`
Expected: FAIL — `github_user.dart` doesn't exist / `Target of URI doesn't exist`.

- [ ] **Step 3: Write the model**

```dart
// lib/features/repo_setup/data/models/github_user.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'github_user.freezed.dart';
part 'github_user.g.dart';

@freezed
sealed class GithubUser with _$GithubUser {
  const factory GithubUser({
    required String login,
    @JsonKey(name: 'avatar_url') required String avatarUrl,
    String? name,
  }) = _GithubUser;

  factory GithubUser.fromJson(Map<String, dynamic> json) => _$GithubUserFromJson(json);
}
```

- [ ] **Step 4: Generate code**

Run: `dart run build_runner build -d`
Expected: creates `github_user.freezed.dart` and `github_user.g.dart`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/repo_setup/data/models/github_user_test.dart`
Expected: PASS (both tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/repo_setup/data/models/github_user.dart test/features/repo_setup/data/models/github_user_test.dart
git commit -m "feat(repo_setup): add GithubUser model"
```

---

### Task 2: GithubRepo model

**Files:**
- Create: `lib/features/repo_setup/data/models/github_repo.dart`
- Test: `test/features/repo_setup/data/models/github_repo_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/repo_setup/data/models/github_repo_test.dart
//
// Test summary:
// - GithubRepo.fromJson maps full_name, owner.login, private, pushed_at, description.
// - pushedAt is null when absent; description is null when absent.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';

void main() {
  test('fromJson maps the GitHub repo payload', () {
    final repo = GithubRepo.fromJson(const {
      'name': 'platform',
      'full_name': 'TurboVets/platform',
      'owner': {'login': 'TurboVets'},
      'description': 'Backend',
      'private': true,
      'pushed_at': '2026-06-10T12:00:00Z',
    });

    expect(repo.name, 'platform');
    expect(repo.nameWithOwner, 'TurboVets/platform');
    expect(repo.owner, 'TurboVets');
    expect(repo.description, 'Backend');
    expect(repo.isPrivate, isTrue);
    expect(repo.pushedAt, DateTime.utc(2026, 6, 10, 12));
  });

  test('fromJson tolerates missing description and pushed_at', () {
    final repo = GithubRepo.fromJson(const {
      'name': 'docs',
      'full_name': 'TurboVets/docs',
      'owner': {'login': 'TurboVets'},
      'private': false,
    });

    expect(repo.description, isNull);
    expect(repo.pushedAt, isNull);
    expect(repo.isPrivate, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/repo_setup/data/models/github_repo_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the model**

`owner` comes from a nested `owner.login`, so we use a small `fromJson` helper rather than a generated nested object.

```dart
// lib/features/repo_setup/data/models/github_repo.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'github_repo.freezed.dart';
part 'github_repo.g.dart';

String _ownerFromJson(Map<String, dynamic> owner) => owner['login'] as String;

@freezed
sealed class GithubRepo with _$GithubRepo {
  const factory GithubRepo({
    required String name,
    @JsonKey(name: 'full_name') required String nameWithOwner,
    @JsonKey(name: 'owner', fromJson: _ownerFromJson) required String owner,
    String? description,
    @JsonKey(name: 'private') @Default(false) bool isPrivate,
    @JsonKey(name: 'pushed_at') DateTime? pushedAt,
  }) = _GithubRepo;

  factory GithubRepo.fromJson(Map<String, dynamic> json) => _$GithubRepoFromJson(json);
}
```

- [ ] **Step 4: Generate code**

Run: `dart run build_runner build -d`
Expected: creates `github_repo.freezed.dart` and `github_repo.g.dart`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/repo_setup/data/models/github_repo_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/repo_setup/data/models/github_repo.dart test/features/repo_setup/data/models/github_repo_test.dart
git commit -m "feat(repo_setup): add GithubRepo model"
```

---

### Task 3: TokenStore (secure storage wrapper + in-memory fake)

**Files:**
- Create: `lib/features/repo_setup/data/services/token_store.dart`

No standalone unit test — `flutter_secure_storage` needs platform channels. We define an interface plus an in-memory fake used by provider tests in later tasks. This task is verified by `dart analyze`.

- [ ] **Step 1: Write the interface + implementations**

```dart
// lib/features/repo_setup/data/services/token_store.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the GitHub personal access token. Never logged.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

/// Backed by flutter_secure_storage (Keychain / Keystore / WebCrypto).
///
/// Web caveat: on web, keys are protected by WebCrypto and do NOT survive a
/// browser-data clear — the user re-enters the token after such a clear.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  static const _key = 'github_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// In-memory fake for tests and offline development.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> delete() async => _token = null;
}
```

- [ ] **Step 2: Verify analysis is clean**

Run: `dart analyze lib/features/repo_setup/data/services/token_store.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/repo_setup/data/services/token_store.dart
git commit -m "feat(repo_setup): add TokenStore (secure + in-memory)"
```

---

### Task 4: GithubApiClient (dedicated Dio + bearer interceptor)

**Files:**
- Create: `lib/features/repo_setup/data/services/github_api_client.dart`

Verified by `dart analyze`; behavior is exercised through `AuthRepository` tests (Task 5), which inject a mocked `Dio`.

- [ ] **Step 1: Write the client**

```dart
// lib/features/repo_setup/data/services/github_api_client.dart
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
```

- [ ] **Step 2: Verify analysis is clean**

Run: `dart analyze lib/features/repo_setup/data/services/github_api_client.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/repo_setup/data/services/github_api_client.dart
git commit -m "feat(repo_setup): add GitHub-scoped Dio client"
```

---

### Task 5: AuthRepository (validate token + list repos with pagination)

**Files:**
- Create: `lib/features/repo_setup/data/repositories/auth_repository.dart`
- Test: `test/features/repo_setup/data/repositories/auth_repository_test.dart`

- [ ] **Step 1: Write the interface + impl + mock**

GitHub `/user` returns the OAuth scopes in the `x-oauth-scopes` response header (comma-separated). We require `repo` and `read:org`.

```dart
// lib/features/repo_setup/data/repositories/auth_repository.dart
import 'dart:developer';

import 'package:dio/dio.dart';
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
  static const _requiredScopes = {'repo', 'read:org'};

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
      String? path =
          '/user/repos?affiliation=owner,collaborator,organization_member&per_page=100&sort=pushed';

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
```

- [ ] **Step 2: Write the failing test**

```dart
// test/features/repo_setup/data/repositories/auth_repository_test.dart
//
// Test summary:
// - validateToken: 200 + required scopes -> success(user)
// - validateToken: 401 -> failure("Invalid or expired token.")
// - validateToken: 200 but missing scope -> failure listing missing scope
// - listAccessibleRepos: follows Link rel="next" across two pages and concatenates
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
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

  Response<T> resp<T>(T? data, {int status = 200, Map<String, List<String>> headers = const {}}) =>
      Response<T>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: status,
        data: data,
        headers: Headers.fromMap(headers),
      );

  test('validateToken returns the user on 200 with required scopes', () async {
    when(dio.get<Map<String, dynamic>>('/user')).thenAnswer((_) async => resp<Map<String, dynamic>>(
          {'login': 'octocat', 'avatar_url': 'x', 'name': 'Octo'},
          headers: {
            'x-oauth-scopes': ['repo, read:org'],
          },
        ));

    final result = await repo.validateToken('tok');

    expect(result, isA<ResultSuccess<GithubUser>>());
    expect((result as ResultSuccess<GithubUser>).data.login, 'octocat');
  });

  test('validateToken fails on 401', () async {
    when(dio.get<Map<String, dynamic>>('/user'))
        .thenAnswer((_) async => resp<Map<String, dynamic>>(null, status: 401));

    final result = await repo.validateToken('bad');

    expect(result, isA<ResultFailure<GithubUser>>());
    expect((result as ResultFailure<GithubUser>).message, contains('Invalid or expired'));
  });

  test('validateToken fails when a required scope is missing', () async {
    when(dio.get<Map<String, dynamic>>('/user')).thenAnswer((_) async => resp<Map<String, dynamic>>(
          {'login': 'octocat', 'avatar_url': 'x'},
          headers: {
            'x-oauth-scopes': ['repo'],
          },
        ));

    final result = await repo.validateToken('tok');

    expect(result, isA<ResultFailure<GithubUser>>());
    expect((result as ResultFailure<GithubUser>).message, contains('read:org'));
  });

  test('listAccessibleRepos follows Link pagination', () async {
    const firstPath = '/user/repos?affiliation=owner,collaborator,organization_member&per_page=100&sort=pushed';
    when(dio.get<List<dynamic>>(firstPath)).thenAnswer((_) async => resp<List<dynamic>>(
          [
            {'name': 'a', 'full_name': 'o/a', 'owner': {'login': 'o'}, 'private': false},
          ],
          headers: {
            'link': ['<https://api.github.com/user/repos?page=2>; rel="next"'],
          },
        ));
    when(dio.get<List<dynamic>>('https://api.github.com/user/repos?page=2'))
        .thenAnswer((_) async => resp<List<dynamic>>([
              {'name': 'b', 'full_name': 'o/b', 'owner': {'login': 'o'}, 'private': false},
            ]));

    final result = await repo.listAccessibleRepos();

    expect(result, isA<ResultSuccess<List<GithubRepo>>>());
    final repos = (result as ResultSuccess<List<GithubRepo>>).data;
    expect(repos.map((r) => r.name), ['a', 'b']);
  });
}
```

- [ ] **Step 3: Generate mocks**

Run: `dart run build_runner build -d`
Expected: creates `test/features/repo_setup/data/repositories/auth_repository_test.mocks.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/repo_setup/data/repositories/auth_repository_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/repo_setup/data/repositories/auth_repository.dart test/features/repo_setup/data/repositories/auth_repository_test.dart
git commit -m "feat(repo_setup): add AuthRepository with token validation and repo pagination"
```

---

### Task 6: WatchedReposNotifier (shared_preferences)

**Files:**
- Create: `lib/features/repo_setup/presentation/providers/watched_repos_provider.dart`
- Test: `test/features/repo_setup/presentation/providers/watched_repos_provider_test.dart`

- [ ] **Step 1: Write the provider**

```dart
// lib/features/repo_setup/presentation/providers/watched_repos_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'watched_repos_provider.g.dart';

const _prefsKey = 'watched_repos';

/// The set of watched repo slugs ("owner/name"), persisted to shared_preferences.
@Riverpod(keepAlive: true)
class WatchedReposNotifier extends _$WatchedReposNotifier {
  @override
  List<String> build() {
    // Hydrated asynchronously after first build via [load].
    return const [];
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefsKey) ?? const [];
  }

  bool isWatched(String slug) => state.contains(slug);

  Future<void> toggle(String slug) async {
    final next = state.contains(slug) ? (state.toList()..remove(slug)) : (state.toList()..add(slug));
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, next);
  }
}
```

- [ ] **Step 2: Generate code**

Run: `dart run build_runner build -d`
Expected: creates `watched_repos_provider.g.dart`.

- [ ] **Step 3: Write the failing test**

```dart
// test/features/repo_setup/presentation/providers/watched_repos_provider_test.dart
//
// Test summary:
// - load() hydrates state from shared_preferences
// - toggle() adds then removes a slug and persists
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/watched_repos_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('load hydrates from shared_preferences', () async {
    SharedPreferences.setMockInitialValues({
      'watched_repos': ['o/a', 'o/b'],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(watchedReposNotifierProvider.notifier).load();

    expect(container.read(watchedReposNotifierProvider), ['o/a', 'o/b']);
  });

  test('toggle adds then removes and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(watchedReposNotifierProvider.notifier);

    await notifier.toggle('o/a');
    expect(container.read(watchedReposNotifierProvider), ['o/a']);
    expect(notifier.isWatched('o/a'), isTrue);

    await notifier.toggle('o/a');
    expect(container.read(watchedReposNotifierProvider), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('watched_repos'), isEmpty);
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/repo_setup/presentation/providers/watched_repos_provider_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/repo_setup/presentation/providers/watched_repos_provider.dart test/features/repo_setup/presentation/providers/watched_repos_provider_test.dart
git commit -m "feat(repo_setup): add WatchedReposNotifier"
```

---

### Task 7: AuthState + AuthStateNotifier + provider wiring

**Files:**
- Create: `lib/features/repo_setup/presentation/providers/auth_provider.dart`
- Test: `test/features/repo_setup/presentation/providers/auth_provider_test.dart`

- [ ] **Step 1: Write the providers + state**

```dart
// lib/features/repo_setup/presentation/providers/auth_provider.dart
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

@riverpod
Future<List<GithubRepo>> accessibleRepos(Ref ref) async {
  final result = await ref.watch(authRepositoryProvider).listAccessibleRepos();
  return switch (result) {
    ResultSuccess(:final data) => data,
    ResultFailure(:final message) => throw Exception(message),
  };
}
```

- [ ] **Step 2: Generate code**

Run: `dart run build_runner build -d`
Expected: creates `auth_provider.freezed.dart` and `auth_provider.g.dart`.

- [ ] **Step 3: Write the failing test**

```dart
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
  Future<Result<GithubUser>> validateToken(String token) async => failMessage != null
      ? Result.failure(failMessage!, StackTrace.current)
      : Result.success(user!);

  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async => Result.success(const []);
}

ProviderContainer makeContainer({required AuthRepository repo, TokenStore? store}) {
  final container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(repo),
    tokenStoreProvider.overrideWithValue(store ?? InMemoryTokenStore()),
  ]);
  addTearDown(container.dispose);
  return container;
}

const _user = GithubUser(login: 'octocat', avatarUrl: '', name: 'Octo');

void main() {
  test('boot with no token resolves to unauthenticated', () async {
    final container = makeContainer(repo: _FakeAuthRepo(user: _user));
    // Trigger build + async _init.
    container.read(authStateNotifierProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authStateNotifierProvider), isA<AuthUnauthenticated>());
  });

  test('boot with a stored token resolves to authenticated', () async {
    final container = makeContainer(repo: _FakeAuthRepo(user: _user), store: InMemoryTokenStore('tok'));
    container.read(authStateNotifierProvider);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(authStateNotifierProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.login, 'octocat');
  });

  test('submitToken success authenticates and writes the token', () async {
    final store = InMemoryTokenStore();
    final container = makeContainer(repo: _FakeAuthRepo(user: _user), store: store);
    await container.read(authStateNotifierProvider.notifier).submitToken('tok');

    expect(container.read(authStateNotifierProvider), isA<AuthAuthenticated>());
    expect(await store.read(), 'tok');
  });

  test('submitToken failure surfaces an error message', () async {
    final container = makeContainer(repo: _FakeAuthRepo(failMessage: 'Invalid or expired token.'));
    await container.read(authStateNotifierProvider.notifier).submitToken('bad');

    final state = container.read(authStateNotifierProvider);
    expect(state, isA<AuthError>());
    expect((state as AuthError).message, 'Invalid or expired token.');
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/repo_setup/presentation/providers/auth_provider_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/repo_setup/presentation/providers/auth_provider.dart test/features/repo_setup/presentation/providers/auth_provider_test.dart
git commit -m "feat(repo_setup): add AuthState and AuthStateNotifier"
```

---

### Task 8: Step indicator widget

**Files:**
- Create: `lib/features/repo_setup/presentation/view/widgets/auth_step_indicator.dart`

Pure presentation; verified by `dart analyze` and used in Task 10's widget test.

- [ ] **Step 1: Write the widget**

```dart
// lib/features/repo_setup/presentation/view/widgets/auth_step_indicator.dart
import 'package:flutter/material.dart';
import 'package:turbo_ui/turbo_ui.dart';

/// Two-segment progress bar for the setup wizard (mockup `.steps`/`.step`).
class AuthStepIndicator extends StatelessWidget {
  const AuthStepIndicator({super.key, required this.currentStep, this.stepCount = 2});

  /// 0-based index of the active step.
  final int currentStep;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: List.generate(stepCount, (i) {
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i == stepCount - 1 ? 0 : 8),
            color: i <= currentStep ? colors.background.accent : colors.border.subtle,
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 2: Verify analysis**

Run: `dart analyze lib/features/repo_setup/presentation/view/widgets/auth_step_indicator.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/repo_setup/presentation/view/widgets/auth_step_indicator.dart
git commit -m "feat(repo_setup): add auth step indicator widget"
```

---

### Task 9: Repo pick list widget

**Files:**
- Create: `lib/features/repo_setup/presentation/view/widgets/repo_pick_list.dart`

- [ ] **Step 1: Write the widget**

Renders the filtered, owner-grouped repo list. It is a pure widget: takes the repo list, the watched-slug set, the filter query, and a toggle callback, so it can be tested without providers.

```dart
// lib/features/repo_setup/presentation/view/widgets/repo_pick_list.dart
import 'package:flutter/material.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../data/models/github_repo.dart';

class RepoPickList extends StatelessWidget {
  const RepoPickList({
    super.key,
    required this.repos,
    required this.watched,
    required this.query,
    required this.onToggle,
  });

  final List<GithubRepo> repos;
  final Set<String> watched;
  final String query;
  final void Function(GithubRepo repo) onToggle;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? repos
        : repos.where((r) => r.nameWithOwner.toLowerCase().contains(q)).toList();

    if (filtered.isEmpty) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No matching repositories.')));
    }

    // Group by owner, owners alphabetical, repos by name within owner.
    final byOwner = <String, List<GithubRepo>>{};
    for (final r in filtered) {
      byOwner.putIfAbsent(r.owner, () => []).add(r);
    }
    final owners = byOwner.keys.toList()..sort();

    final colors = context.appColors;
    return ListView(
      shrinkWrap: true,
      children: [
        for (final owner in owners) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(owner, style: TextStyle(color: colors.foreground.primaryMuted, fontSize: 12)),
          ),
          for (final repo in byOwner[owner]!..sort((a, b) => a.name.compareTo(b.name)))
            TetherListItem(
              title: repo.name,
              subtitle: repo.description,
              showTrailing: true,
              trailing: TetherSwitch(
                value: watched.contains(repo.nameWithOwner),
                semanticsLabel: 'Watch ${repo.nameWithOwner}',
                onChanged: (_) => onToggle(repo),
              ),
              onTap: () => onToggle(repo),
            ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: Verify analysis**

Run: `dart analyze lib/features/repo_setup/presentation/view/widgets/repo_pick_list.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/repo_setup/presentation/view/widgets/repo_pick_list.dart
git commit -m "feat(repo_setup): add repo pick list widget"
```

---

### Task 10: Setup screen (2-step wizard)

**Files:**
- Create: `lib/features/repo_setup/presentation/view/setup_screen.dart`
- Test: `test/features/repo_setup/presentation/view/setup_screen_test.dart`

- [ ] **Step 1: Write the screen**

```dart
// lib/features/repo_setup/presentation/view/setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../providers/auth_provider.dart';
import '../providers/watched_repos_provider.dart';
import 'widgets/auth_step_indicator.dart';
import 'widgets/repo_pick_list.dart';

/// First-run wizard: paste a PAT (step 1), pick watched repos (step 2).
class SetupScreen extends HookConsumerWidget {
  const SetupScreen({super.key});

  static const String routeName = 'setup';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final authState = ref.watch(authStateNotifierProvider);
    final tokenController = useTextEditingController();
    final query = useState('');

    final onStep2 = authState is AuthAuthenticated;

    return Scaffold(
      backgroundColor: colors.background.primary,
      body: Center(
        child: SizedBox(
          width: 452,
          child: TetherCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthStepIndicator(currentStep: onStep2 ? 1 : 0),
                const SizedBox(height: 24),
                if (!onStep2)
                  _ConnectStep(authState: authState, controller: tokenController, ref: ref)
                else
                  _ReposStep(query: query, ref: ref),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectStep extends StatelessWidget {
  const _ConnectStep({required this.authState, required this.controller, required this.ref});

  final AuthState authState;
  final TextEditingController controller;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isValidating = authState is AuthValidating;
    final errorText = authState is AuthError ? authState.message : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('TurboBoard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Paste a GitHub personal access token to watch every open PR across your repos.'),
        const SizedBox(height: 20),
        TetherTextField(
          label: 'GitHub token',
          hintText: 'ghp_…',
          obscureText: true,
          controller: controller,
          errorText: errorText,
          enabled: !isValidating,
          onSubmitted: (_) => ref.read(authStateNotifierProvider.notifier).submitToken(controller.text.trim()),
        ),
        const SizedBox(height: 8),
        const Text('Needs the `repo` and `read:org` scopes. Create one at github.com/settings/tokens.'),
        const SizedBox(height: 16),
        if (isValidating)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
        else
          TetherActionButton(
            label: 'Validate & continue',
            isExpanded: true,
            onPressed: () => ref.read(authStateNotifierProvider.notifier).submitToken(controller.text.trim()),
          ),
      ],
    );
  }
}

class _ReposStep extends StatelessWidget {
  const _ReposStep({required this.query, required this.ref});

  final ValueNotifier<String> query;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final reposAsync = ref.watch(accessibleReposProvider);
    final watched = ref.watch(watchedReposNotifierProvider).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Watched repos', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TetherSearchField(hintText: 'Filter repositories', onChanged: (v) => query.value = v),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: reposAsync.when(
            data: (repos) => RepoPickList(
              repos: repos,
              watched: watched,
              query: query.value,
              onToggle: (r) => ref.read(watchedReposNotifierProvider.notifier).toggle(r.nameWithOwner),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load repos: $e')),
          ),
        ),
        const SizedBox(height: 16),
        TetherActionButton(
          label: 'Open PR Board →',
          isExpanded: true,
          onPressed: watched.isEmpty ? null : () => context.go('/'),
        ),
      ],
    );
  }
}
```

The `/setup` route and the `/` board route both exist after Task 11; `context.go('/')` resolves once routing is wired. The screen compiles now because `context.go` comes from the already-imported go_router.

- [ ] **Step 2: Write the failing widget test**

```dart
// test/features/repo_setup/presentation/view/setup_screen_test.dart
//
// Test summary:
// - Step 1 shows the token field and validate button.
// - submitting an invalid token shows the error text (provider returns AuthError).
// - when authenticated, step 2 shows the repo list and toggling a repo enables "Open PR Board".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';
import 'package:turbo_board/features/repo_setup/data/repositories/auth_repository.dart';
import 'package:turbo_board/features/repo_setup/data/services/token_store.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/auth_provider.dart';
import 'package:turbo_board/features/repo_setup/presentation/view/setup_screen.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';

class _Repo implements AuthRepository {
  _Repo({this.fail = false});
  final bool fail;

  @override
  Future<Result<GithubUser>> validateToken(String token) async => fail
      ? Result.failure('Invalid or expired token.', StackTrace.current)
      : Result.success(const GithubUser(login: 'octocat', avatarUrl: ''));

  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async => Result.success(const [
        GithubRepo(name: 'platform', nameWithOwner: 'TurboVets/platform', owner: 'TurboVets'),
      ]);
}

Widget _app(AuthRepository repo) => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
      child: MaterialApp(theme: getAppTheme(), home: const SetupScreen()),
    );

void main() {
  testWidgets('step 1 shows token field and validate button', (tester) async {
    await tester.pumpWidget(_app(_Repo()));
    await tester.pumpAndSettle();

    expect(find.text('Validate & continue'), findsOneWidget);
    expect(find.text('Watched repos'), findsNothing);
  });

  testWidgets('invalid token surfaces an error', (tester) async {
    await tester.pumpWidget(_app(_Repo(fail: true)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'bad');
    await tester.tap(find.text('Validate & continue'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid or expired token.'), findsOneWidget);
  });

  testWidgets('valid token advances to step 2', (tester) async {
    await tester.pumpWidget(_app(_Repo()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'goodtoken');
    await tester.tap(find.text('Validate & continue'));
    await tester.pumpAndSettle();

    expect(find.text('Watched repos'), findsOneWidget);
    expect(find.text('platform'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `flutter test test/features/repo_setup/presentation/view/setup_screen_test.dart`
Expected: PASS (3 tests). If the `TetherTextField` renders more than one `TextField`, narrow the finder with `find.byType(TextField).first` (already used).

- [ ] **Step 4: Commit**

```bash
git add lib/features/repo_setup/presentation/view/ test/features/repo_setup/presentation/view/setup_screen_test.dart
git commit -m "feat(repo_setup): add setup wizard screen"
```

---

### Task 11: Routing — /setup route + auth redirect guard

**Files:**
- Modify: `lib/shared/router/app_router.dart`
- Test: `test/shared/router/app_router_test.dart`

- [ ] **Step 1: Update the router**

```dart
// lib/shared/router/app_router.dart
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/pr_inbox/presentation/view/pr_inbox_screen.dart';
import '../../features/repo_setup/presentation/providers/auth_provider.dart';
import '../../features/repo_setup/presentation/view/setup_screen.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Re-run redirects whenever auth state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateNotifierProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateNotifierProvider);
      final onSetup = state.matchedLocation == '/setup';
      return switch (auth) {
        AuthValidating() => null, // don't bounce mid-validation
        AuthAuthenticated() => onSetup ? '/' : null,
        _ => onSetup ? null : '/setup', // unauthenticated / error
      };
    },
    routes: [
      GoRoute(
        path: '/',
        name: PrInboxScreen.routeName,
        builder: (context, state) => const PrInboxScreen(),
      ),
      GoRoute(
        path: '/setup',
        name: SetupScreen.routeName,
        builder: (context, state) => const SetupScreen(),
      ),
    ],
  );
}
```

- [ ] **Step 2: Generate code**

Run: `dart run build_runner build -d`
Expected: regenerates `app_router.g.dart`.

- [ ] **Step 3: Write the failing redirect test**

```dart
// test/shared/router/app_router_test.dart
//
// Test summary:
// - unauthenticated user is redirected from '/' to '/setup'
// - authenticated user lands on '/' (PR inbox)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';
import 'package:turbo_board/features/repo_setup/data/repositories/auth_repository.dart';
import 'package:turbo_board/features/repo_setup/data/services/token_store.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/auth_provider.dart';
import 'package:turbo_board/features/repo_setup/presentation/view/setup_screen.dart';
import 'package:turbo_board/shared/router/app_router.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';

class _Repo implements AuthRepository {
  _Repo(this.user);
  final GithubUser? user;
  @override
  Future<Result<GithubUser>> validateToken(String token) async =>
      user != null ? Result.success(user!) : Result.failure('no', StackTrace.current);
  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async => Result.success(const []);
}

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: Builder(builder: (context) {
        final router = c.read(appRouterProvider);
        return MaterialApp.router(theme: getAppTheme(), routerConfig: router);
      }),
    );

void main() {
  testWidgets('unauthenticated user is sent to /setup', (tester) async {
    final c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_Repo(null)),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    expect(find.byType(SetupScreen), findsOneWidget);
  });

  testWidgets('authenticated user lands on the board', (tester) async {
    final c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_Repo(const GithubUser(login: 'o', avatarUrl: ''))),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore('tok')),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    expect(find.byType(SetupScreen), findsNothing);
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/router/app_router_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/shared/router/app_router.dart test/shared/router/app_router_test.dart
git commit -m "feat(repo_setup): gate routing on auth state"
```

---

### Task 12: Full-suite verification + format + analyze

**Files:** none (verification only)

- [ ] **Step 1: Format**

Run: `dart format --line-length 120 .`
Then: `dart format --line-length 120 --set-exit-if-changed .`
Expected: "0 changed".

- [ ] **Step 2: Analyze**

Run: `dart analyze`
Expected: "No issues found!" (If unused-import warnings on the deleted `_board_nav.dart` import appear, remove them.)

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all tests pass (existing pr_inbox tests + new repo_setup + router tests).

- [ ] **Step 4: Manual smoke (one desktop + web)**

Run: `flutter run -d macos` then `flutter run -d chrome`.
Expected: app launches to the setup screen (no stored token), token field visible. (Real GitHub validation needs a real PAT; mock can be temporarily wired via `authRepositoryProvider.overrideWith` in `main` if testing offline.)

- [ ] **Step 5: Commit any formatting fixups**

```bash
git add -A
git commit -m "chore(repo_setup): format and analyze pass"
```

---

## Notes for the implementer

- **Run order matters:** models (Tasks 1–2) and providers (6, 7) require `dart run build_runner build -d` before their tests compile. The mock for Task 5 is also generated by build_runner.
- **Do not log the token** anywhere (`log`, `print`, error messages). Error strings are generic.
- **`AuthState` is a Freezed union** — match it with `switch` and the generated subtypes (`AuthValidating`, `AuthUnauthenticated`, `AuthAuthenticated`, `AuthError`).
- **`TetherActionButton` has no loading prop** — the connect step swaps the button for a `CircularProgressIndicator` while `AuthValidating`.
- This plan is sub-project **A**. Sub-project **B** (real PR inbox + 3-region shell) consumes `githubApiClientProvider` and `watchedReposNotifierProvider` produced here.
```
