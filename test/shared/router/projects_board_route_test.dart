// test/shared/router/projects_board_route_test.dart
//
// Test summary:
// - The app router resolves '/projects' to ProjectsBoardScreen.
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/projects_board/presentation/view/projects_board_screen.dart';
import 'package:turbo_board/features/repo_setup/data/services/token_store.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/auth_provider.dart';
import 'package:turbo_board/shared/router/app_router.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('router has a /projects route named projectsBoard', () {
    final c = ProviderContainer(overrides: [tokenStoreProvider.overrideWithValue(InMemoryTokenStore())]);
    addTearDown(c.dispose);
    final router = c.read(appRouterProvider);
    final match = router.configuration.findMatch(Uri.parse('/projects'));
    expect(match.routes.whereType<GoRoute>().any((r) => r.name == ProjectsBoardScreen.routeName), isTrue);
  });
}
