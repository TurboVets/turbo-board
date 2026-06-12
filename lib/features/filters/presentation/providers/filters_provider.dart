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

  void toggleStatus(PrStatus s) => state = state.copyWith(statuses: _toggle(state.statuses, s));

  void toggleReviewState(PrReviewState s) => state = state.copyWith(reviewStates: _toggle(state.reviewStates, s));

  void toggleCiState(PrCiState s) => state = state.copyWith(ciStates: _toggle(state.ciStates, s));

  static Set<T> _toggle<T>(Set<T> set, T value) {
    final next = set.toSet();
    next.contains(value) ? next.remove(value) : next.add(value);
    return next;
  }
}
