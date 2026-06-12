# PR Board (GitHub-backed Inbox) + 3-Region Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mock PR inbox with a live GitHub-GraphQL-backed PR Board (kanban columns by review state) inside a responsive three-region Tether shell (nav rail + content).

**Architecture:** A shared `AppShell` (left rail + routed content) wraps the board via a go_router `ShellRoute`; `/setup` stays bare. PRs are fetched with one GraphQL `search` query POSTed through the existing token-authed `GithubApiClient` (from sub-project A) and mapped to the existing `PrData` model. Errors are caught only in the repository and surfaced as `Result<T>`. Riverpod (codegen) wires it; the board groups PRs into four `PrReviewState` columns in the widget layer.

**Tech Stack:** Flutter, Riverpod (codegen) + flutter_hooks, Freezed, go_router, dio (GraphQL POST), turbo_ui (Tether), lucide_icons_flutter, timeago, mockito (test).

---

## Reference (read before starting)

- Spec: `docs/superpowers/specs/2026-06-11-pr-inbox-board-design.md`
- Sub-project A is done. Reusable pieces:
  - `GithubApiClient` (`lib/features/repo_setup/data/services/github_api_client.dart`) — exposes `final Dio dio` (base `https://api.github.com`, `Authorization: Bearer …` already set after auth) and `setToken`.
  - `githubApiClientProvider`, `authStateProvider` (AuthState union: `AuthValidating`/`AuthUnauthenticated`/`AuthAuthenticated(user)`/`AuthError`), `watchedReposProvider` (List<String> slugs) — all in `lib/features/repo_setup/presentation/providers/auth_provider.dart` and `watched_repos_provider.dart`.
  - `GithubUser` (`login`, `avatarUrl`, `name?`).
- Existing pr_inbox (to be modified/rebuilt): `lib/features/pr_inbox/data/models/pr_data.dart` (PrData, `PrReviewState`, `PrCiState`), `data/repositories/pr_inbox_repository.dart` (interface + `MockPrInboxRepository`), `presentation/providers/pr_inbox_provider.dart`, `presentation/view/pr_inbox_screen.dart` (scaffold — will be rebuilt).
- turbo_ui components (verified signatures):
  - `TetherIconButton({required IconData icon, TetherButtonType type, TetherButtonSize size, Color? iconColor, Color? background, Color? borderColor, VoidCallback? onPressed, String? semanticsLabel, String? semanticsHint})`
  - `TetherBadge({required String label, TetherBadgeType type=soft, TetherBadgeColor color=gray, TetherBadgeSize size=regular, IconData? icon, Widget? iconWidget, bool isRounded=false, VoidCallback? onTap})`
  - `TetherBadgeColor { red, yellow, green, blue, purple, orange, teal, gray }`
  - `TetherSignalDot({TetherBadgeColor color=gray, double size=12, String? semanticsLabel})`
  - `TetherAvatar({ImageProvider? imageProvider, String? initials, TetherAvatarSize size=md, ..., String? semanticsLabel, VoidCallback? onTap})`
  - `TetherCard({required Widget child, VoidCallback? onTap, EdgeInsetsGeometry? padding, double? borderRadius, Color? backgroundColor, Color? borderColor, ...})`
  - `context.appColors` → `background`/`foreground`/`border` groups (`.primary`, `.secondary`, `.accent`, `.success`, `.alert`, `.primaryMuted`, `border.subtle`, etc.).
- After model/provider changes: `dart run build_runner build -d`. Generated files are gitignored — never commit them.
- Signal mapping (used for badges/dots):
  - CI: `passing`→green, `pending`→yellow, `failing`→red.
  - Review: `needsReview`→blue, `changesRequested`→red, `approved`→green, `waitingOnAuthor`→gray.

## File structure

```
lib/features/pr_inbox/
├── data/
│   ├── models/pr_data.dart                 # MODIFY: add commentsCount
│   ├── queries/search_open_prs.dart        # NEW: GraphQL doc + query-string builder
│   └── repositories/pr_inbox_repository.dart # MODIFY: add GithubPrInboxRepository + node→PrData mapper
├── presentation/
│   ├── providers/pr_inbox_provider.dart    # MODIFY: wire real repo from client + watched repos
│   └── view/
│       ├── pr_inbox_screen.dart            # REBUILD: PR Board (topbar + 4 columns + states)
│       └── widgets/
│           ├── pr_card.dart                # NEW
│           └── pr_column.dart              # NEW
lib/features/repo_setup/data/services/github_api_client.dart  # MODIFY: add graphql()
lib/shared/ui/shell/
├── app_shell.dart                          # NEW: responsive 3-region scaffold
└── nav_rail.dart                           # NEW: left rail
lib/shared/router/app_router.dart           # MODIFY: ShellRoute around '/'

test/features/pr_inbox/...                  # mapping, repo, board tests
test/features/repo_setup/data/services/github_api_client_test.dart  # NEW: graphql()
test/shared/ui/shell/app_shell_test.dart    # NEW
```

---

### Task 1: Add `commentsCount` to PrData

**Files:**
- Modify: `lib/features/pr_inbox/data/models/pr_data.dart`
- Test: `test/features/pr_inbox/data/models/pr_data_test.dart` (new)

- [ ] **Step 1: Write the failing test**

```dart
// test/features/pr_inbox/data/models/pr_data_test.dart
//
// Test summary:
// - commentsCount defaults to 0 when omitted.
// - commentsCount round-trips through the constructor.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';

void main() {
  PrData make({int? comments}) => PrData(
        repo: 'o/r',
        number: 1,
        title: 't',
        author: 'a',
        reviewState: PrReviewState.needsReview,
        ciState: PrCiState.passing,
        updatedAt: DateTime(2026, 1, 1),
        commentsCount: comments ?? 0,
      );

  test('commentsCount defaults to 0', () {
    final pr = PrData(
      repo: 'o/r',
      number: 1,
      title: 't',
      author: 'a',
      reviewState: PrReviewState.needsReview,
      ciState: PrCiState.passing,
      updatedAt: DateTime(2026, 1, 1),
    );
    expect(pr.commentsCount, 0);
  });

  test('commentsCount is retained', () {
    expect(make(comments: 7).commentsCount, 7);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/pr_inbox/data/models/pr_data_test.dart`
Expected: FAIL — `commentsCount` is not a parameter.

- [ ] **Step 3: Add the field**

In `lib/features/pr_inbox/data/models/pr_data.dart`, add to the `PrData` factory (after `htmlUrl`):

```dart
    String? htmlUrl,
    @Default(0) int commentsCount,
  }) = _PrData;
```

- [ ] **Step 4: Generate code**

Run: `dart run build_runner build -d`
Expected: regenerates `pr_data.freezed.dart` / `pr_data.g.dart`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/pr_inbox/data/models/pr_data_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/pr_inbox/data/models/pr_data.dart test/features/pr_inbox/data/models/pr_data_test.dart
git commit -m "feat(pr_inbox): add commentsCount to PrData"
```

---

### Task 2: `GithubApiClient.graphql()`

**Files:**
- Modify: `lib/features/repo_setup/data/services/github_api_client.dart`
- Test: `test/features/repo_setup/data/services/github_api_client_test.dart` (new)

- [ ] **Step 1: Write the failing test**

```dart
// test/features/repo_setup/data/services/github_api_client_test.dart
//
// Test summary:
// - graphql() returns the `data` map on a 200 with no errors.
// - graphql() throws when the response contains a non-empty `errors` array.
// - graphql() throws on a non-200 status.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/repo_setup/data/services/github_api_client.dart';

import 'github_api_client_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio dio;
  late GithubApiClient client;

  setUp(() {
    dio = MockDio();
    when(dio.options).thenReturn(BaseOptions());
    client = GithubApiClient(dio: dio);
  });

  Response<Map<String, dynamic>> resp(Map<String, dynamic>? data, {int status = 200}) => Response(
        requestOptions: RequestOptions(path: '/graphql'),
        statusCode: status,
        data: data,
      );

  test('returns data on success', () async {
    when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer(
      (_) async => resp({
        'data': {'search': {'nodes': []}},
      }),
    );

    final data = await client.graphql('query{}', const {});

    expect(data, containsPair('search', isA<Map<String, dynamic>>()));
  });

  test('throws on GraphQL errors array', () async {
    when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer(
      (_) async => resp({
        'errors': [
          {'message': 'Bad credentials'},
        ],
      }),
    );

    expect(() => client.graphql('query{}', const {}), throwsA(isA<Exception>()));
  });

  test('throws on non-200', () async {
    when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data')))
        .thenAnswer((_) async => resp(null, status: 401));

    expect(() => client.graphql('query{}', const {}), throwsA(isA<Exception>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart run build_runner build -d` (generates the Dio mock), then
`flutter test test/features/repo_setup/data/services/github_api_client_test.dart`
Expected: FAIL — `graphql` is not defined.

- [ ] **Step 3: Add the method**

In `lib/features/repo_setup/data/services/github_api_client.dart`, add inside the class (after `setToken`):

```dart
  /// POSTs a GraphQL [query] with [variables] to GitHub's GraphQL endpoint and
  /// returns the top-level `data` map. Throws on a non-200 status or when the
  /// response carries a non-empty top-level `errors` array.
  Future<Map<String, dynamic>> graphql(String query, Map<String, dynamic> variables) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/graphql',
      data: {'query': query, 'variables': variables},
    );
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/repo_setup/data/services/github_api_client_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/repo_setup/data/services/github_api_client.dart test/features/repo_setup/data/services/github_api_client_test.dart
git commit -m "feat(repo_setup): add GraphQL POST to GithubApiClient"
```

---

### Task 3: Search query document + query-string builder

**Files:**
- Create: `lib/features/pr_inbox/data/queries/search_open_prs.dart`
- Test: `test/features/pr_inbox/data/queries/search_open_prs_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/pr_inbox/data/queries/search_open_prs_test.dart
//
// Test summary:
// - buildSearchQueryString prefixes is:pr is:open and adds a repo: term per slug.
// - slugs are deduped and sorted for a stable query.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/queries/search_open_prs.dart';

void main() {
  test('builds an is:pr is:open query with repo terms', () {
    final q = buildSearchQueryString(['o/b', 'o/a']);
    expect(q, 'is:pr is:open repo:o/a repo:o/b');
  });

  test('dedupes repeated slugs', () {
    final q = buildSearchQueryString(['o/a', 'o/a', 'o/b']);
    expect(q, 'is:pr is:open repo:o/a repo:o/b');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/pr_inbox/data/queries/search_open_prs_test.dart`
Expected: FAIL — file/function missing.

- [ ] **Step 3: Write the query + builder**

```dart
// lib/features/pr_inbox/data/queries/search_open_prs.dart

/// GraphQL document fetching open PRs across the watched repos.
/// `$q` is the search expression (see [buildSearchQueryString]); `$first` caps results.
const String searchOpenPrsQuery = r'''
query SearchOpenPrs($q: String!, $first: Int!) {
  search(query: $q, type: ISSUE, first: $first) {
    nodes {
      ... on PullRequest {
        number
        title
        isDraft
        updatedAt
        url
        author { login }
        repository { nameWithOwner }
        reviewDecision
        comments { totalCount }
        commits(last: 1) {
          nodes { commit { statusCheckRollup { state } } }
        }
      }
    }
  }
}
''';

/// Builds the GitHub search expression: `is:pr is:open repo:<slug> …`.
/// Slugs are deduped and sorted so the query (and any caching) is stable.
String buildSearchQueryString(List<String> repoSlugs) {
  final slugs = repoSlugs.toSet().toList()..sort();
  final terms = slugs.map((s) => 'repo:$s').join(' ');
  return terms.isEmpty ? 'is:pr is:open' : 'is:pr is:open $terms';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/pr_inbox/data/queries/search_open_prs_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/pr_inbox/data/queries/search_open_prs.dart test/features/pr_inbox/data/queries/search_open_prs_test.dart
git commit -m "feat(pr_inbox): add open-PR search query and builder"
```

---

### Task 4: `GithubPrInboxRepository` (+ GraphQL node → PrData mapping)

**Files:**
- Modify: `lib/features/pr_inbox/data/repositories/pr_inbox_repository.dart`
- Test: `test/features/pr_inbox/data/repositories/pr_inbox_repository_test.dart` (extend existing)

- [ ] **Step 1: Add the repository + mapper**

Append to `lib/features/pr_inbox/data/repositories/pr_inbox_repository.dart` (keep the existing interface + `MockPrInboxRepository` + sample data). Add imports at top: `import 'dart:developer';` (if not present), `import 'package:turbo_core/core.dart';` (present), and `import '../../../repo_setup/data/services/github_api_client.dart';`, `import '../queries/search_open_prs.dart';`.

```dart
/// Fetches open PRs across the watched repos via GitHub's GraphQL search.
class GithubPrInboxRepository implements PrInboxRepository {
  GithubPrInboxRepository(this._client, this._watchedRepos);

  final GithubApiClient _client;
  final List<String> _watchedRepos;

  @override
  Future<Result<List<PrData>>> fetchOpenPrs() async {
    if (_watchedRepos.isEmpty) return Result.success(const []);
    try {
      final data = await _client.graphql(searchOpenPrsQuery, {
        'q': buildSearchQueryString(_watchedRepos),
        'first': 50,
      });
      final nodes = (data['search']?['nodes'] as List<dynamic>?) ?? const [];
      final prs = nodes
          .whereType<Map<String, dynamic>>()
          .map(prFromSearchNode)
          .whereType<PrData>()
          .toList();
      return Result.success(prs);
    } catch (e, stackTrace) {
      log('Failed to fetch open PRs', error: e, stackTrace: stackTrace);
      return Result.failure('Could not load pull requests.', stackTrace);
    }
  }
}

/// Maps one GraphQL `search.nodes` entry to a [PrData]. Returns null for empty
/// nodes (non-PullRequest results have no `number` under the inline fragment).
PrData? prFromSearchNode(Map<String, dynamic> node) {
  final number = node['number'];
  if (number is! int) return null;

  final rollupState =
      ((node['commits']?['nodes'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?)?['commit']?['statusCheckRollup']?['state'] as String?;

  return PrData(
    repo: (node['repository']?['nameWithOwner'] as String?) ?? '',
    number: number,
    title: (node['title'] as String?) ?? '',
    author: (node['author']?['login'] as String?) ?? 'unknown',
    isDraft: (node['isDraft'] as bool?) ?? false,
    reviewState: _reviewStateFrom(node['reviewDecision'] as String?),
    ciState: _ciStateFrom(rollupState),
    updatedAt: DateTime.tryParse((node['updatedAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    htmlUrl: node['url'] as String?,
    commentsCount: (node['comments']?['totalCount'] as int?) ?? 0,
  );
}

PrReviewState _reviewStateFrom(String? decision) => switch (decision) {
      'REVIEW_REQUIRED' => PrReviewState.needsReview,
      'CHANGES_REQUESTED' => PrReviewState.changesRequested,
      'APPROVED' => PrReviewState.approved,
      _ => PrReviewState.waitingOnAuthor,
    };

PrCiState _ciStateFrom(String? rollup) => switch (rollup) {
      'SUCCESS' => PrCiState.passing,
      'FAILURE' || 'ERROR' => PrCiState.failing,
      _ => PrCiState.pending,
    };
```

Note: `firstOrNull` comes from `package:collection` (already a dependency) — add `import 'package:collection/collection.dart';` at the top of the file.

- [ ] **Step 2: Write the failing tests**

Add these to the existing `test/features/pr_inbox/data/repositories/pr_inbox_repository_test.dart` (keep the existing MockPrInboxRepository tests). Add a `@GenerateMocks([Dio])` annotation and the imports. If the file has no `@GenerateMocks` yet, add it above `void main()`.

```dart
// (add to imports)
import 'package:dio/dio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_board/features/pr_inbox/data/queries/search_open_prs.dart';
import 'package:turbo_board/features/repo_setup/data/services/github_api_client.dart';
import 'pr_inbox_repository_test.mocks.dart';

// (add above main)
@GenerateMocks([Dio])

// (add inside main(), as a new group)
  group('GithubPrInboxRepository', () {
    late MockDio dio;

    setUp(() {
      dio = MockDio();
      when(dio.options).thenReturn(BaseOptions());
    });

    Response<Map<String, dynamic>> ok(Map<String, dynamic> data) => Response(
          requestOptions: RequestOptions(path: '/graphql'),
          statusCode: 200,
          data: {'data': data},
        );

    test('returns empty list when no repos are watched (no network call)', () async {
      final repo = GithubPrInboxRepository(GithubApiClient(dio: dio), const []);
      final result = await repo.fetchOpenPrs();
      expect(result, isA<ResultSuccess<List<PrData>>>());
      expect((result as ResultSuccess<List<PrData>>).data, isEmpty);
      verifyNever(dio.post<Map<String, dynamic>>(any, data: anyNamed('data')));
    });

    test('maps a PullRequest node across review and CI states', () async {
      when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer(
        (_) async => ok({
          'search': {
            'nodes': [
              {
                'number': 42,
                'title': 'Add thing',
                'isDraft': false,
                'updatedAt': '2026-06-10T12:00:00Z',
                'url': 'https://github.com/o/r/pull/42',
                'author': {'login': 'sang'},
                'repository': {'nameWithOwner': 'o/r'},
                'reviewDecision': 'CHANGES_REQUESTED',
                'comments': {'totalCount': 4},
                'commits': {
                  'nodes': [
                    {'commit': {'statusCheckRollup': {'state': 'FAILURE'}}},
                  ],
                },
              },
              {}, // non-PR node -> skipped
            ],
          },
        }),
      );

      final repo = GithubPrInboxRepository(GithubApiClient(dio: dio), ['o/r']);
      final result = await repo.fetchOpenPrs();

      final prs = (result as ResultSuccess<List<PrData>>).data;
      expect(prs, hasLength(1));
      expect(prs.single.number, 42);
      expect(prs.single.repo, 'o/r');
      expect(prs.single.author, 'sang');
      expect(prs.single.reviewState, PrReviewState.changesRequested);
      expect(prs.single.ciState, PrCiState.failing);
      expect(prs.single.commentsCount, 4);
    });

    test('null reviewDecision maps to waitingOnAuthor and missing rollup to pending', () async {
      when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer(
        (_) async => ok({
          'search': {
            'nodes': [
              {
                'number': 1,
                'title': 't',
                'updatedAt': '2026-06-10T12:00:00Z',
                'author': {'login': 'a'},
                'repository': {'nameWithOwner': 'o/r'},
                'reviewDecision': null,
                'comments': {'totalCount': 0},
                'commits': {'nodes': []},
              },
            ],
          },
        }),
      );
      final repo = GithubPrInboxRepository(GithubApiClient(dio: dio), ['o/r']);
      final prs = (await repo.fetchOpenPrs() as ResultSuccess<List<PrData>>).data;
      expect(prs.single.reviewState, PrReviewState.waitingOnAuthor);
      expect(prs.single.ciState, PrCiState.pending);
    });

    test('returns failure when the GraphQL call throws', () async {
      when(dio.post<Map<String, dynamic>>('/graphql', data: anyNamed('data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/graphql'),
          statusCode: 200,
          data: {
            'errors': [
              {'message': 'Bad credentials'},
            ],
          },
        ),
      );
      final repo = GithubPrInboxRepository(GithubApiClient(dio: dio), ['o/r']);
      final result = await repo.fetchOpenPrs();
      expect(result, isA<ResultFailure<List<PrData>>>());
    });
  });
```

- [ ] **Step 3: Generate mocks**

Run: `dart run build_runner build -d`
Expected: creates/updates `test/features/pr_inbox/data/repositories/pr_inbox_repository_test.mocks.dart`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/pr_inbox/data/repositories/pr_inbox_repository_test.dart`
Expected: PASS (existing MockPrInboxRepository tests + 4 new ones).

- [ ] **Step 5: Commit**

```bash
git add lib/features/pr_inbox/data/repositories/pr_inbox_repository.dart test/features/pr_inbox/data/repositories/pr_inbox_repository_test.dart
git commit -m "feat(pr_inbox): add GitHub GraphQL-backed PR repository"
```

---

### Task 5: Wire the real repository into the provider

**Files:**
- Modify: `lib/features/pr_inbox/presentation/providers/pr_inbox_provider.dart`

The existing `prInboxProvider` shape is unchanged; only the default repository changes. The existing provider test overrides `prInboxRepositoryProvider`, so it stays green.

- [ ] **Step 1: Update the repository provider**

Replace the body of `prInboxRepositoryProvider` in `lib/features/pr_inbox/presentation/providers/pr_inbox_provider.dart`. New full file:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../../repo_setup/presentation/providers/watched_repos_provider.dart';
import '../../data/models/pr_data.dart';
import '../../data/repositories/pr_inbox_repository.dart';

part 'pr_inbox_provider.g.dart';

@Riverpod(keepAlive: true)
PrInboxRepository prInboxRepository(Ref ref) {
  final client = ref.watch(githubApiClientProvider);
  final watched = ref.watch(watchedReposProvider);
  return GithubPrInboxRepository(client, watched);
}

@riverpod
Future<List<PrData>> prInbox(Ref ref) async {
  final repo = ref.watch(prInboxRepositoryProvider);
  final result = await repo.fetchOpenPrs();

  return switch (result) {
    ResultSuccess(:final data) => data,
    ResultFailure(:final message) => throw Exception(message),
  };
}
```

- [ ] **Step 2: Generate code**

Run: `dart run build_runner build -d`
Expected: regenerates `pr_inbox_provider.g.dart` (no signature change).

- [ ] **Step 3: Run the provider + repo tests**

Run: `flutter test test/features/pr_inbox/`
Expected: PASS (the existing provider test overrides the repo; mapping/repo tests pass).

- [ ] **Step 4: Commit**

```bash
git add lib/features/pr_inbox/presentation/providers/pr_inbox_provider.dart
git commit -m "feat(pr_inbox): provide the GitHub-backed repository from watched repos"
```

---

### Task 6: `PrCard` widget

**Files:**
- Create: `lib/features/pr_inbox/presentation/view/widgets/pr_card.dart`
- Test: `test/features/pr_inbox/presentation/view/widgets/pr_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/pr_inbox/presentation/view/widgets/pr_card_test.dart
//
// Test summary:
// - renders the title, slug, author and a CI/review badge for a PR.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_card.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

void main() {
  testWidgets('renders title, slug and author', (tester) async {
    final pr = PrData(
      repo: 'o/r',
      number: 42,
      title: 'Add rate limiting',
      author: 'sang',
      reviewState: PrReviewState.needsReview,
      ciState: PrCiState.passing,
      updatedAt: DateTime(2026, 6, 10),
      commentsCount: 3,
    );

    await tester.pumpWidget(MaterialApp(theme: getAppTheme(), home: Scaffold(body: PrCard(pr: pr))));

    expect(find.text('Add rate limiting'), findsOneWidget);
    expect(find.textContaining('o/r#42'), findsOneWidget);
    expect(find.textContaining('sang'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/pr_inbox/presentation/view/widgets/pr_card_test.dart`
Expected: FAIL — `PrCard` missing.

- [ ] **Step 3: Write the widget**

```dart
// lib/features/pr_inbox/presentation/view/widgets/pr_card.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turbo_ui/turbo_ui.dart';

import '../../../data/models/pr_data.dart';

/// A single PR row on the board. Display-only in sub-project B (tap is a no-op;
/// PR Detail arrives in sub-project D).
class PrCard extends StatelessWidget {
  const PrCard({super.key, required this.pr});

  final PrData pr;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return TetherCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                pr.isDraft ? LucideIcons.gitPullRequestDraft : LucideIcons.gitPullRequest,
                size: 18,
                color: colors.foreground.link,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(pr.title, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${pr.slug} · ${pr.author} · ${timeago.format(pr.updatedAt)}',
            style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TetherBadge(label: _ciLabel(pr.ciState), color: _ciColor(pr.ciState), size: TetherBadgeSize.small),
              TetherBadge(
                label: _reviewLabel(pr.reviewState),
                color: _reviewColor(pr.reviewState),
                size: TetherBadgeSize.small,
              ),
              if (pr.commentsCount > 0)
                TetherBadge(
                  label: '${pr.commentsCount}',
                  icon: LucideIcons.messageSquare,
                  color: TetherBadgeColor.gray,
                  size: TetherBadgeSize.small,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _ciLabel(PrCiState s) => switch (s) {
      PrCiState.passing => 'Checks',
      PrCiState.pending => 'Checks',
      PrCiState.failing => 'Checks',
    };

TetherBadgeColor _ciColor(PrCiState s) => switch (s) {
      PrCiState.passing => TetherBadgeColor.green,
      PrCiState.pending => TetherBadgeColor.yellow,
      PrCiState.failing => TetherBadgeColor.red,
    };

String _reviewLabel(PrReviewState s) => switch (s) {
      PrReviewState.needsReview => 'Needs review',
      PrReviewState.changesRequested => 'Changes req',
      PrReviewState.approved => 'Approved',
      PrReviewState.waitingOnAuthor => 'Waiting',
    };

TetherBadgeColor _reviewColor(PrReviewState s) => switch (s) {
      PrReviewState.needsReview => TetherBadgeColor.blue,
      PrReviewState.changesRequested => TetherBadgeColor.red,
      PrReviewState.approved => TetherBadgeColor.green,
      PrReviewState.waitingOnAuthor => TetherBadgeColor.gray,
    };
```

Note: `pr.slug` already exists on `PrData` (`'$repo#$number'`). If `TetherBadge`'s `icon` param type is not `IconData`, drop the `icon:` on the comment badge and prefix the label instead — REPORT the change.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/pr_inbox/presentation/view/widgets/pr_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/pr_inbox/presentation/view/widgets/pr_card.dart test/features/pr_inbox/presentation/view/widgets/pr_card_test.dart
git commit -m "feat(pr_inbox): add PrCard widget"
```

---

### Task 7: `PrColumn` widget

**Files:**
- Create: `lib/features/pr_inbox/presentation/view/widgets/pr_column.dart`
- Test: `test/features/pr_inbox/presentation/view/widgets/pr_column_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/pr_inbox/presentation/view/widgets/pr_column_test.dart
//
// Test summary:
// - shows the column title and the item count.
// - renders one PrCard per item; shows "None" when empty.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_card.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_column.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

PrData _pr(int n) => PrData(
      repo: 'o/r',
      number: n,
      title: 'PR $n',
      author: 'a',
      reviewState: PrReviewState.needsReview,
      ciState: PrCiState.passing,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('shows title, count and a card per item', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: getAppTheme(),
      home: Scaffold(body: PrColumn(title: 'Needs review', prs: [_pr(1), _pr(2)])),
    ));

    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(PrCard), findsNWidgets(2));
  });

  testWidgets('shows None when empty', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: getAppTheme(),
      home: const Scaffold(body: PrColumn(title: 'Approved', prs: [])),
    ));

    expect(find.text('None'), findsOneWidget);
    expect(find.byType(PrCard), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/pr_inbox/presentation/view/widgets/pr_column_test.dart`
Expected: FAIL — `PrColumn` missing.

- [ ] **Step 3: Write the widget**

```dart
// lib/features/pr_inbox/presentation/view/widgets/pr_column.dart
import 'package:flutter/material.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../data/models/pr_data.dart';
import 'pr_card.dart';

/// One board column: a header (title + count) over a scrollable list of [PrCard]s.
///
/// Fills the height it is given (it uses [Expanded] internally), so the parent
/// MUST constrain its height — the board wraps each column in a height-bounded
/// `SizedBox` (see [_Board]). In tests, a `Scaffold` body provides that bound.
class PrColumn extends StatelessWidget {
  const PrColumn({super.key, required this.title, required this.prs});

  final String title;
  final List<PrData> prs;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            children: [
              Text(title, style: text.titleSmall),
              const SizedBox(width: 8),
              Text('${prs.length}', style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted)),
            ],
          ),
        ),
        Expanded(
          child: prs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('None', style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: prs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => PrCard(pr: prs[i]),
                ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/pr_inbox/presentation/view/widgets/pr_column_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/pr_inbox/presentation/view/widgets/pr_column.dart test/features/pr_inbox/presentation/view/widgets/pr_column_test.dart
git commit -m "feat(pr_inbox): add PrColumn widget"
```

---

### Task 8: Rebuild the board screen (PR Board)

**Files:**
- Modify (full rewrite): `lib/features/pr_inbox/presentation/view/pr_inbox_screen.dart`
- Test: `test/features/pr_inbox/presentation/view/pr_inbox_screen_test.dart` (new)

- [ ] **Step 1: Rewrite the screen**

```dart
// lib/features/pr_inbox/presentation/view/pr_inbox_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../data/models/pr_data.dart';
import '../providers/pr_inbox_provider.dart';
import 'widgets/pr_column.dart';

/// The PR Board — open PRs across watched repos, in columns by review state.
class PrInboxScreen extends ConsumerWidget {
  const PrInboxScreen({super.key});

  static const String routeName = 'prInbox';

  // Column order, left to right.
  static const _columns = <(PrReviewState, String)>[
    (PrReviewState.needsReview, 'Needs review'),
    (PrReviewState.changesRequested, 'Changes requested'),
    (PrReviewState.approved, 'Approved'),
    (PrReviewState.waitingOnAuthor, 'Waiting'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prs = ref.watch(prInboxProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('PR Board', style: text.headlineSmall),
              const Spacer(),
              TetherIconButton(
                icon: LucideIcons.refreshCw,
                type: TetherButtonType.ghost,
                semanticsLabel: 'Refresh',
                onPressed: () => ref.invalidate(prInboxProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: prs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _ErrorState(message: '$err', onRetry: () => ref.invalidate(prInboxProvider)),
            data: (items) => items.isEmpty
                ? const _EmptyState()
                : _Board(items: items),
          ),
        ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.items});

  final List<PrData> items;

  @override
  Widget build(BuildContext context) {
    // Each column uses Expanded internally, so it needs a bounded height; give
    // it the viewport height (minus the 8px vertical padding) and a fixed width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnHeight = constraints.maxHeight - 16;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (state, title) in PrInboxScreen._columns) ...[
                SizedBox(
                  width: 320,
                  height: columnHeight > 0 ? columnHeight : null,
                  child: PrColumn(title: title, prs: items.where((p) => p.reviewState == state).toList()),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No open PRs. Pick repos to watch in setup, or enjoy the calm.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load PRs.\n$message', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TetherActionButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}
```

Note: the board is the routed child rendered inside `AppShell` (Task 11), so it returns a `Column`, not its own `Scaffold`. If a test needs a Scaffold ancestor, the test wraps it (see below).

- [ ] **Step 2: Write the failing test**

```dart
// test/features/pr_inbox/presentation/view/pr_inbox_screen_test.dart
//
// Test summary:
// - groups PRs into the four review-state columns with correct counts.
// - shows the empty state when there are no PRs.
// - shows an error state with a Retry action when the provider throws.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/data/repositories/pr_inbox_repository.dart';
import 'package:turbo_board/features/pr_inbox/presentation/providers/pr_inbox_provider.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/pr_inbox_screen.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_card.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';

class _StaticRepo implements PrInboxRepository {
  _StaticRepo(this.prs);
  final List<PrData> prs;
  @override
  Future<Result<List<PrData>>> fetchOpenPrs() async => Result.success(prs);
}

class _FailingRepo implements PrInboxRepository {
  @override
  Future<Result<List<PrData>>> fetchOpenPrs() async => Result.failure('boom', StackTrace.current);
}

PrData _pr(int n, PrReviewState s) => PrData(
      repo: 'o/r',
      number: n,
      title: 'PR $n',
      author: 'a',
      reviewState: s,
      ciState: PrCiState.passing,
      updatedAt: DateTime(2026, 1, 1),
    );

Widget _host(PrInboxRepository repo) => ProviderScope(
      overrides: [prInboxRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: getAppTheme(), home: const Scaffold(body: PrInboxScreen())),
    );

void main() {
  testWidgets('groups PRs into review-state columns', (tester) async {
    await tester.pumpWidget(_host(_StaticRepo([
      _pr(1, PrReviewState.needsReview),
      _pr(2, PrReviewState.needsReview),
      _pr(3, PrReviewState.approved),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('PR Board'), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.byType(PrCard), findsNWidgets(3));
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(_host(_StaticRepo(const [])));
    await tester.pumpAndSettle();
    expect(find.textContaining('No open PRs'), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_host(_FailingRepo()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load PRs'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `flutter test test/features/pr_inbox/presentation/view/pr_inbox_screen_test.dart`
Expected: PASS (3 tests). If the horizontal `SingleChildScrollView` + `Expanded` columns overflow in the test surface, the columns have fixed width 320 inside an unbounded horizontal scroll — that's fine; `pumpAndSettle` won't error. If a height-unbounded error appears, ensure the test `Scaffold` gives the screen a bounded height (it does).

- [ ] **Step 4: Commit**

```bash
git add lib/features/pr_inbox/presentation/view/pr_inbox_screen.dart test/features/pr_inbox/presentation/view/pr_inbox_screen_test.dart
git commit -m "feat(pr_inbox): rebuild board as PR Board with review-state columns"
```

---

### Task 9: `AppNavRail` widget

**Files:**
- Create: `lib/shared/ui/shell/nav_rail.dart`
- Test: `test/shared/ui/shell/nav_rail_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/ui/shell/nav_rail_test.dart
//
// Test summary:
// - renders the PR Board nav entry and the watched repos.
// - shows the authenticated user's login.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';
import 'package:turbo_board/features/repo_setup/data/repositories/auth_repository.dart';
import 'package:turbo_board/features/repo_setup/data/services/token_store.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/auth_provider.dart';
import 'package:turbo_board/shared/ui/shell/nav_rail.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';

class _Repo implements AuthRepository {
  @override
  Future<Result<GithubUser>> validateToken(String token) async =>
      Result.success(const GithubUser(login: 'octocat', avatarUrl: ''));
  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async => Result.success(const []);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'watched_repos': ['TurboVets/platform'],
    });
  });

  testWidgets('shows nav entries, watched repos and user', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Repo()),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore('tok')),
      ],
      child: MaterialApp(theme: getAppTheme(), home: const Scaffold(body: AppNavRail(collapsed: false))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PR Board'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.textContaining('platform'), findsOneWidget);
    expect(find.textContaining('octocat'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/ui/shell/nav_rail_test.dart`
Expected: FAIL — `AppNavRail` missing.

- [ ] **Step 3: Write the widget**

```dart
// lib/shared/ui/shell/nav_rail.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../features/repo_setup/presentation/providers/auth_provider.dart';
import '../../../features/repo_setup/presentation/providers/watched_repos_provider.dart';

/// Left navigation rail of the app shell. [collapsed] hides labels (tablet).
class AppNavRail extends ConsumerWidget {
  const AppNavRail({super.key, required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final watched = ref.watch(watchedReposProvider);
    final auth = ref.watch(authStateProvider);
    final text = Theme.of(context).textTheme;

    final login = switch (auth) {
      AuthAuthenticated(:final user) => user.login,
      _ => null,
    };

    return Container(
      width: collapsed ? 64 : 240,
      color: colors.background.secondary,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(LucideIcons.crosshair, color: colors.foreground.link),
          ),
          const SizedBox(height: 24),
          // Workspace nav
          _NavItem(icon: LucideIcons.layoutGrid, label: 'PR Board', collapsed: collapsed, active: true, onTap: () => context.go('/')),
          _NavItem(icon: LucideIcons.circleDot, label: 'Needs attention', collapsed: collapsed, enabled: false),
          _NavItem(icon: LucideIcons.settings2, label: 'Filters', collapsed: collapsed, enabled: false),
          _NavItem(icon: LucideIcons.circleDashed, label: 'Issues', collapsed: collapsed, enabled: false),
          const SizedBox(height: 16),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text('Watched repos', style: text.labelSmall?.copyWith(color: colors.foreground.primaryMuted)),
            ),
          Expanded(
            child: ListView(
              children: [
                for (final slug in watched)
                  _RepoItem(slug: slug, collapsed: collapsed),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // User footer + sign out
          Row(
            children: [
              TetherAvatar(initials: _initials(login), size: TetherAvatarSize.sm),
              if (!collapsed) ...[
                const SizedBox(width: 8),
                Expanded(child: Text(login ?? '—', style: text.bodySmall, overflow: TextOverflow.ellipsis)),
              ],
              TetherIconButton(
                icon: LucideIcons.logOut,
                type: TetherButtonType.ghost,
                size: TetherButtonSize.small,
                semanticsLabel: 'Sign out',
                onPressed: () => ref.read(authStateProvider.notifier).signOut(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String? login) {
    if (login == null || login.isEmpty) return '?';
    return login.substring(0, login.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    this.active = false,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool collapsed;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fg = !enabled
        ? colors.foreground.onDisabled
        : active
            ? colors.foreground.link
            : colors.foreground.primary;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: fg)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RepoItem extends StatelessWidget {
  const _RepoItem({required this.slug, required this.collapsed});

  final String slug;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final name = slug.contains('/') ? slug.split('/').last : slug;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          const TetherSignalDot(color: TetherBadgeColor.green, size: 8),
          if (!collapsed) ...[
            const SizedBox(width: 8),
            Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ],
      ),
    );
  }
}
```

Note: verify the lucide icon names (`crosshair`, `layoutGrid`, `circleDot`, `settings2`, `circleDashed`, `logOut`) exist in `lucide_icons_flutter`. If any name differs, substitute the closest existing icon and REPORT it. The watched-repo dot color is fixed green in B (per-repo CI rollup colors arrive with a richer repo model later).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/ui/shell/nav_rail_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/ui/shell/nav_rail.dart test/shared/ui/shell/nav_rail_test.dart
git commit -m "feat(shell): add app nav rail"
```

---

### Task 10: `AppShell` (responsive 3-region scaffold)

**Files:**
- Create: `lib/shared/ui/shell/app_shell.dart`
- Test: `test/shared/ui/shell/app_shell_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/ui/shell/app_shell_test.dart
//
// Test summary:
// - renders the rail and the routed child.
// - at tablet width (<1100) the rail collapses (no text labels).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';
import 'package:turbo_board/features/repo_setup/data/repositories/auth_repository.dart';
import 'package:turbo_board/features/repo_setup/data/services/token_store.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/auth_provider.dart';
import 'package:turbo_board/shared/ui/shell/app_shell.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';

class _Repo implements AuthRepository {
  @override
  Future<Result<GithubUser>> validateToken(String token) async =>
      Result.success(const GithubUser(login: 'octocat', avatarUrl: ''));
  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async => Result.success(const []);
}

Widget _host({required Size size}) => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Repo()),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore('tok')),
      ],
      child: MaterialApp(
        theme: getAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const AppShell(child: Text('ROUTED-CHILD')),
        ),
      ),
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('desktop width shows labelled rail and child', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(size: const Size(1400, 900)));
    await tester.pumpAndSettle();

    expect(find.text('ROUTED-CHILD'), findsOneWidget);
    expect(find.text('PR Board'), findsOneWidget); // label visible on desktop
  });

  testWidgets('tablet width collapses the rail (no PR Board label)', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(size: const Size(900, 800)));
    await tester.pumpAndSettle();

    expect(find.text('ROUTED-CHILD'), findsOneWidget);
    expect(find.text('PR Board'), findsNothing); // collapsed rail hides labels
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/ui/shell/app_shell_test.dart`
Expected: FAIL — `AppShell` missing.

- [ ] **Step 3: Write the widget**

```dart
// lib/shared/ui/shell/app_shell.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_ui/turbo_ui.dart';

import 'nav_rail.dart';

/// Responsive three-region shell: a left nav rail beside the routed [child].
/// The right detail/filter region arrives in later sub-projects.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// Below this width the rail collapses to icons (tablet). No phone layout.
  static const double _collapseBelow = 1100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background.primary,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed = constraints.maxWidth < _collapseBelow;
          return Row(
            children: [
              AppNavRail(collapsed: collapsed),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/ui/shell/app_shell_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/shared/ui/shell/app_shell.dart test/shared/ui/shell/app_shell_test.dart
git commit -m "feat(shell): add responsive AppShell"
```

---

### Task 11: Wrap the board route in a `ShellRoute`

**Files:**
- Modify: `lib/shared/router/app_router.dart`
- Test: `test/shared/router/app_router_test.dart` (extend)

- [ ] **Step 1: Update the router**

In `lib/shared/router/app_router.dart`, add `import '../ui/shell/app_shell.dart';` and replace the `routes:` list so `/` lives inside a `ShellRoute`, `/setup` stays outside:

```dart
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', name: PrInboxScreen.routeName, builder: (context, state) => const PrInboxScreen()),
        ],
      ),
      GoRoute(path: '/setup', name: SetupScreen.routeName, builder: (context, state) => const SetupScreen()),
    ],
```

Leave the `refreshListenable`, `redirect`, `initialLocation` unchanged.

- [ ] **Step 2: Generate code**

Run: `dart run build_runner build -d`
Expected: regenerates `app_router.g.dart` (no signature change).

- [ ] **Step 3: Extend the router test**

Add a test to `test/shared/router/app_router_test.dart` confirming the board now renders inside the shell. Add imports `import 'package:turbo_board/shared/ui/shell/app_shell.dart';` and `import 'package:turbo_board/features/pr_inbox/presentation/view/pr_inbox_screen.dart';` (if not present), plus `import 'package:shared_preferences/shared_preferences.dart';`. Add to `setUp` (create one if absent): `TestWidgetsFlutterBinding.ensureInitialized(); SharedPreferences.setMockInitialValues({});`. Then:

```dart
  testWidgets('authenticated board renders inside the AppShell', (tester) async {
    final c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_Repo(const GithubUser(login: 'o', avatarUrl: ''))),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore('tok')),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(PrInboxScreen), findsOneWidget);
  });
```

Note: the existing `_Repo` fake in that file returns `Result.success(const [])` for `listAccessibleRepos`; the board's `prInboxProvider` will use the real `GithubPrInboxRepository` built from `githubApiClientProvider` + empty watched repos (no token-backed network because watched is empty → returns empty list). So the board shows its empty state inside the shell — `find.byType(PrInboxScreen)` still matches. If `pumpAndSettle` times out, pump a fixed `const Duration(seconds: 1)` and REPORT it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/shared/router/app_router_test.dart`
Expected: PASS (existing 3 + 1 new).

- [ ] **Step 5: Commit**

```bash
git add lib/shared/router/app_router.dart test/shared/router/app_router_test.dart
git commit -m "feat(shell): host the board inside the app shell via ShellRoute"
```

---

### Task 12: Full verification (format / analyze / test / build)

**Files:** none (verification only)

- [ ] **Step 1: Format**

Run: `dart format --line-length 120 .`
Then: `dart format --line-length 120 --set-exit-if-changed .`
Expected: "0 changed".

- [ ] **Step 2: Analyze**

Run: `dart analyze`
Expected: "No issues found!" Fix any lint (e.g. unused imports left from the screen rewrite, wildcard-underscore lints `(_, _)`).

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all tests pass (A's repo_setup + pr_inbox + shell + router).

- [ ] **Step 4: Compile check**

Run: `flutter build web --no-tree-shake-icons`
Expected: "✓ Built build/web" (wasm dry-run warnings about flutter_secure_storage are expected and harmless).

- [ ] **Step 5: Manual smoke (real PAT, ≥1 watched repo)**

`flutter run -d macos` then `-d chrome`: sign in (A) → pick a repo → "Open PR Board →" → the board shows real open PRs from the watched repo, grouped into the four columns, with CI/review badges. Refresh re-fetches. Sign-out (rail footer) returns to `/setup`.

- [ ] **Step 6: Commit any formatting fixups**

```bash
git add -A
git commit -m "chore(pr_inbox): format and analyze pass for PR Board + shell"
```

---

## Notes for the implementer

- **Build order:** Tasks 1, 4, 5, 11 touch generated code — run `dart run build_runner build -d` where indicated. The Dio mocks for Tasks 2 and 4 are also generated by build_runner.
- **Never log the token.** The repository's `log(...)` calls pass only the error/stack.
- **`PrData.slug`** is `'$repo#$number'` (already defined). The board groups by `reviewState` purely in the widget layer.
- **Cross-feature imports:** `pr_inbox` now imports `repo_setup` providers/services (`githubApiClientProvider`, `watchedReposProvider`, `GithubApiClient`). This is the intended dependency direction (the board consumes auth + watched repos).
- **turbo_ui API drift:** if any named param or icon constant differs from what's written here, read the real source under `~/.pub-cache/git/mobile-shared-components-*/packages/turbo_ui/` (or `lucide_icons_flutter`) and adapt minimally, reporting the change. Do not invent params.
- This is sub-project **B**. Needs Attention + Filters (C) wire the disabled rail entries and add the right-hand filter column; PR Detail (D) makes `PrCard` tappable.
