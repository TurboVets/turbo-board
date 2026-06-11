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
  child: Builder(
    builder: (context) {
      final router = c.read(appRouterProvider);
      return MaterialApp.router(theme: getAppTheme(), routerConfig: router);
    },
  ),
);

void main() {
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
}
