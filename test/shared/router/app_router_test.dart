// test/shared/router/app_router_test.dart
//
// Test summary:
// - unauthenticated user is redirected from '/' to '/setup'
// - authenticated user lands on '/' (PR inbox)
// - full setup flow: step 1 -> validate -> step 2 (watched repos) -> board
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/pr_inbox_screen.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';
import 'package:turbo_board/features/repo_setup/data/repositories/auth_repository.dart';
import 'package:turbo_board/features/repo_setup/data/services/token_store.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/auth_provider.dart';
import 'package:turbo_board/features/repo_setup/presentation/view/setup_screen.dart';
import 'package:turbo_board/shared/router/app_router.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';
import 'package:turbo_ui/turbo_ui.dart';

// Returns empty repos list — used by the two existing tests.
class _Repo implements AuthRepository {
  _Repo(this.user);
  final GithubUser? user;
  @override
  Future<Result<GithubUser>> validateToken(String token) async =>
      user != null ? Result.success(user!) : Result.failure('no', StackTrace.current);
  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async => Result.success(const []);
}

// Returns a non-empty repos list — used by the full-flow integration test.
class _RepoWithRepos implements AuthRepository {
  _RepoWithRepos(this.user, this.repos);
  final GithubUser? user;
  final List<GithubRepo> repos;
  @override
  Future<Result<GithubUser>> validateToken(String token) async =>
      user != null ? Result.success(user!) : Result.failure('no', StackTrace.current);
  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async => Result.success(repos);
}

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: Builder(
    builder: (context) {
      final router = c.read(appRouterProvider);
      return MaterialApp.router(theme: getAppTheme(), routerConfig: router);
    },
  ),
);

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('unauthenticated user is sent to /setup', (tester) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Repo(null)),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    expect(find.byType(SetupScreen), findsOneWidget);
  });

  testWidgets('authenticated user lands on the board', (tester) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Repo(const GithubUser(login: 'o', avatarUrl: ''))),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore('tok')),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    expect(find.byType(SetupScreen), findsNothing);
  });

  testWidgets('full setup flow: step 1 -> validate -> step 2 -> board', (tester) async {
    const testRepo = GithubRepo(name: 'platform', nameWithOwner: 'TurboVets/platform', owner: 'TurboVets');

    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          _RepoWithRepos(const GithubUser(login: 'o', avatarUrl: ''), const [testRepo]),
        ),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    // Step 1: setup screen with token field is shown
    expect(find.byType(SetupScreen), findsOneWidget);
    expect(find.text('Validate & continue'), findsOneWidget);

    // Enter token and tap validate
    await tester.enterText(find.byType(TextField).first, 'goodtoken');
    await tester.tap(find.text('Validate & continue'));
    await tester.pumpAndSettle();

    // Step 2: watched repos section is now visible (regression guard for Bug 1)
    expect(find.text('Watched repos'), findsOneWidget);
    expect(find.text('platform'), findsOneWidget);

    // 'Open PR Board →' button is initially disabled (no repos selected yet)
    final buttonFinder = find.widgetWithText(TetherActionButton, 'Open PR Board →');
    expect(tester.widget<TetherActionButton>(buttonFinder).onPressed, isNull);

    // Toggle the first repo on
    await tester.tap(find.byType(TetherSwitch).first);
    await tester.pumpAndSettle();

    // Button should now be enabled
    expect(tester.widget<TetherActionButton>(buttonFinder).onPressed, isNotNull);

    // Tap 'Open PR Board →' to navigate to the board
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    // Board is shown, setup screen is gone
    expect(find.byType(PrInboxScreen), findsOneWidget);
    expect(find.byType(SetupScreen), findsNothing);
  });
}
