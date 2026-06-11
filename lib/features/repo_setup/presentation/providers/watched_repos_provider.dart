import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'watched_repos_provider.g.dart';

const _prefsKey = 'watched_repos';

/// The set of watched repo slugs ("owner/name"), persisted to shared_preferences.
@Riverpod(keepAlive: true)
class WatchedReposNotifier extends _$WatchedReposNotifier {
  @override
  List<String> build() {
    load(); // hydrate from shared_preferences on first build
    return const [];
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefsKey) ?? const [];
  }

  bool isWatched(String slug) => state.contains(slug);

  Future<void> toggle(String slug) async {
    final next = state.contains(slug) ? (state.toList()..remove(slug)) : (state.toList()..add(slug));
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, next);
  }
}
