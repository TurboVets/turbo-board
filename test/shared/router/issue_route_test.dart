// test/shared/router/issue_route_test.dart
//
// Test summary:
// - The router exposes a route named IssueDetailScreen.routeName under the shell,
//   verified by navigating to it with goNamed and asserting IssueDetailScreen renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/issue_detail_screen.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';
import 'package:turbo_board/features/repo_setup/data/repositories/auth_repository.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';
import 'package:turbo_board/features/repo_setup/data/services/token_store.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/auth_provider.dart';
import 'package:turbo_board/shared/router/app_router.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';

class _AuthRepo implements AuthRepository {
  @override
  Future<Result<GithubUser>> validateToken(String token) async =>
      Result.success(const GithubUser(login: 'o', avatarUrl: ''));
  @override
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async => Result.success(const []);
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

  testWidgets('/issue/:owner/:repo/:number resolves to IssueDetailScreen', (tester) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_AuthRepo()),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore('tok')),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    c
        .read(appRouterProvider)
        .goNamed(IssueDetailScreen.routeName, pathParameters: {'owner': 'o', 'repo': 'r', 'number': '42'});
    await tester.pumpAndSettle();

    expect(find.byType(IssueDetailScreen), findsOneWidget);
  });
}
