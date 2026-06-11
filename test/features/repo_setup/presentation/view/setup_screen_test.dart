// test/features/repo_setup/presentation/view/setup_screen_test.dart
//
// Test summary:
// - Step 1 shows the token field and validate button.
// - Submitting an invalid token shows the error text (provider returns AuthError).
// - Valid token advances to step 2; "Open PR Board →" is initially DISABLED when no repo
//   is watched, then becomes ENABLED after the repo toggle is tapped.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';
import 'package:turbo_board/features/repo_setup/data/repositories/auth_repository.dart';
import 'package:turbo_board/features/repo_setup/data/services/token_store.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/auth_provider.dart';
import 'package:turbo_board/features/repo_setup/presentation/view/setup_screen.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_core/core.dart';
import 'package:turbo_ui/turbo_ui.dart';

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
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

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

  testWidgets('valid token advances to step 2; toggle enables Open PR Board button', (tester) async {
    await tester.pumpWidget(_app(_Repo()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'goodtoken');
    await tester.tap(find.text('Validate & continue'));
    await tester.pumpAndSettle();

    expect(find.text('Watched repos'), findsOneWidget);
    expect(find.text('platform'), findsOneWidget);

    // Button should be DISABLED initially (no repo watched).
    final buttonBefore = tester.widget<TetherActionButton>(find.widgetWithText(TetherActionButton, 'Open PR Board →'));
    expect(buttonBefore.onPressed, isNull);

    // Tap the toggle to watch the 'platform' repo.
    await tester.tap(find.byType(TetherSwitch).first);
    await tester.pumpAndSettle();

    // Button should now be ENABLED.
    final buttonAfter = tester.widget<TetherActionButton>(find.widgetWithText(TetherActionButton, 'Open PR Board →'));
    expect(buttonAfter.onPressed, isNotNull);
  });
}
