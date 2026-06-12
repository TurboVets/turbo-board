import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/pr_detail.dart';

part 'merge_method_provider.g.dart';

const _prefsKey = 'preferred_merge_method';

/// The user's preferred merge strategy, remembered across sessions so the merge
/// split button defaults to their last choice. Stored by enum name. When the
/// repo doesn't allow this strategy the button falls back to the first allowed.
@Riverpod(keepAlive: true)
class MergeMethodPreference extends _$MergeMethodPreference {
  @override
  PrMergeMethod build() {
    load(); // hydrate from shared_preferences on first build
    return PrMergeMethod.squash;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    for (final m in PrMergeMethod.values) {
      if (m.name == stored) {
        state = m;
        return;
      }
    }
  }

  Future<void> set(PrMergeMethod method) async {
    if (method == state) return;
    state = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, method.name);
  }
}
