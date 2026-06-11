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

    await container.read(watchedReposProvider.notifier).load();

    expect(container.read(watchedReposProvider), ['o/a', 'o/b']);
  });

  test('toggle adds then removes and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(watchedReposProvider.notifier);

    await notifier.toggle('o/a');
    expect(container.read(watchedReposProvider), ['o/a']);
    expect(notifier.isWatched('o/a'), isTrue);

    await notifier.toggle('o/a');
    expect(container.read(watchedReposProvider), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('watched_repos'), isEmpty);
  });
}
