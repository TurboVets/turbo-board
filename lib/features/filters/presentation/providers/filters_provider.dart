import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../pr_inbox/data/models/pr_data.dart';
import '../../data/models/pr_filters.dart';

part 'filters_provider.g.dart';

/// The active board filter set. Lives on the PR board (no dedicated screen).
@Riverpod(keepAlive: true)
class ActiveFilters extends _$ActiveFilters {
  @override
  PrFilters build() => const PrFilters();

  void setSortBy(PrSortBy sortBy) => state = state.copyWith(sortBy: sortBy);

  void clear() => state = const PrFilters();

  void toggleRepo(String repo) => state = state.copyWith(repos: _toggle(state.repos, repo));

  /// Toggles a repo's visibility on the board from the nav rail. Unlike
  /// [toggleRepo] (filter bar — builds an allowlist *up* from "all"), this seeds
  /// from the full watched set so a single tap *removes* one repo, matching the
  /// mockup's "click to include / exclude from the board". Collapses back to the
  /// empty (= "all") set once every repo is visible again, so the filter reads
  /// clean. Hiding the last visible repo also collapses to "all" — the board
  /// can't show zero repos.
  void toggleRepoVisibility(String slug, List<String> allWatched) {
    final visible = state.repos.isEmpty ? allWatched.toSet() : state.repos.toSet();
    visible.contains(slug) ? visible.remove(slug) : visible.add(slug);
    final isAll = visible.isEmpty || (visible.length == allWatched.length && visible.containsAll(allWatched));
    state = state.copyWith(repos: isAll ? const <String>{} : visible);
  }

  /// Whether [slug] currently shows on the board: true when no repo facet is
  /// set (all visible) or when the allowlist contains it.
  bool isRepoVisible(String slug) => state.repos.isEmpty || state.repos.contains(slug);

  void toggleStatus(PrStatus s) => state = state.copyWith(statuses: _toggle(state.statuses, s));

  void toggleReviewState(PrReviewState s) => state = state.copyWith(reviewStates: _toggle(state.reviewStates, s));

  void toggleCiState(PrCiState s) => state = state.copyWith(ciStates: _toggle(state.ciStates, s));

  static Set<T> _toggle<T>(Set<T> set, T value) {
    final next = set.toSet();
    next.contains(value) ? next.remove(value) : next.add(value);
    return next;
  }
}
