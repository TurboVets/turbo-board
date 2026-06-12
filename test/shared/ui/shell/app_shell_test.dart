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
