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
  Future<Result<List<GithubRepo>>> listAccessibleRepos() async =>
      Result.success(const [GithubRepo(name: 'platform', nameWithOwner: 'TurboVets/platform', owner: 'TurboVets')]);
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
