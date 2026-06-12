import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../pr_inbox/data/models/pr_data.dart';

part 'pr_filters.freezed.dart';

/// PR lifecycle status used by the status filter. The current inbox dataset
/// only carries open PRs (draft vs. ready), so [merged]/[closed] match nothing
/// until closed-PR data is fetched — kept for forward-compat with scope.
enum PrStatus { open, draft, merged, closed }

/// Sort order for the board. v1 ships a single option.
enum PrSortBy { updatedRecently }

/// The active filter set for the PR board. Empty selections mean "match all"
/// for that facet — so the empty [PrFilters] (the default) is a no-op.
@freezed
sealed class PrFilters with _$PrFilters {
  const PrFilters._();

  const factory PrFilters({
    @Default(<String>{}) Set<String> repos,
    @Default(<PrStatus>{}) Set<PrStatus> statuses,
    @Default(<PrReviewState>{}) Set<PrReviewState> reviewStates,
    @Default(<PrCiState>{}) Set<PrCiState> ciStates,
    @Default(PrSortBy.updatedRecently) PrSortBy sortBy,
  }) = _PrFilters;

  /// True when no facet narrows the result (all sets empty).
  bool get isEmpty => repos.isEmpty && statuses.isEmpty && reviewStates.isEmpty && ciStates.isEmpty;

  /// Number of active (non-empty) facets — drives the "FILTERS (N)" badge.
  int get activeFacetCount =>
      (repos.isEmpty ? 0 : 1) +
      (statuses.isEmpty ? 0 : 1) +
      (reviewStates.isEmpty ? 0 : 1) +
      (ciStates.isEmpty ? 0 : 1);
}
