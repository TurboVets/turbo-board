// test/shared/ui/shell/nav_rail_test.dart
//
// Test summary:
// - renders the PR Board nav entry and the watched repos.
// - shows the authenticated user's login.
// - tapping a watched repo row toggles it out of the board filter (and back).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/filters/presentation/providers/filters_provider.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/presentation/providers/pr_inbox_provider.dart';
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_Repo()),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore('tok')),
          prInboxProvider.overrideWith((ref) async => const <PrData>[]),
        ],
        child: MaterialApp(
          theme: getAppTheme(),
          home: const Scaffold(body: AppNavRail(collapsed: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PR Board'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.textContaining('platform'), findsOneWidget);
    expect(find.textContaining('octocat'), findsOneWidget);
  });

  testWidgets('tapping a watched repo toggles it out of the board filter', (tester) async {
    SharedPreferences.setMockInitialValues({
      'watched_repos': ['TurboVets/platform', 'TurboVets/mobile'],
    });
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Repo()),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore('tok')),
        prInboxProvider.overrideWith((ref) async => const <PrData>[]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: getAppTheme(),
          home: const Scaffold(body: AppNavRail(collapsed: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default: no repo facet → all repos visible.
    expect(container.read(activeFiltersProvider).repos, isEmpty);

    // Tap "platform" → it's excluded; only the others remain in the allowlist.
    await tester.tap(find.textContaining('platform'));
    await tester.pumpAndSettle();
    expect(container.read(activeFiltersProvider).repos, {'TurboVets/mobile'});

    // Tap again → re-included; collapses back to the empty ("all") set.
    await tester.tap(find.textContaining('platform'));
    await tester.pumpAndSettle();
    expect(container.read(activeFiltersProvider).repos, isEmpty);
  });
}
