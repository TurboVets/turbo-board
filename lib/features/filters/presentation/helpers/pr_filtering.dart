import '../../../pr_inbox/data/models/pr_data.dart';
import '../../data/models/pr_filters.dart';

/// Maps a PR to its lifecycle [PrStatus]. The inbox only carries open PRs, so
/// this resolves to [PrStatus.draft] or [PrStatus.open] only.
PrStatus statusOf(PrData pr) => pr.isDraft ? PrStatus.draft : PrStatus.open;

/// Applies [filters] to [prs] and sorts the result. Pure — no I/O, no clock.
///
/// Empty facet sets match everything. Facets combine with AND across facets and
/// OR within a facet (e.g. CI = {failing, pending} keeps PRs failing OR pending).
List<PrData> applyFilters(List<PrData> prs, PrFilters filters) {
  final filtered = prs.where((pr) {
    if (filters.repos.isNotEmpty && !filters.repos.contains(pr.repo)) return false;
    if (filters.statuses.isNotEmpty && !filters.statuses.contains(statusOf(pr))) return false;
    if (filters.reviewStates.isNotEmpty && !filters.reviewStates.contains(pr.reviewState)) return false;
    if (filters.ciStates.isNotEmpty && !filters.ciStates.contains(pr.ciState)) return false;
    return true;
  }).toList();

  switch (filters.sortBy) {
    case PrSortBy.updatedRecently:
      filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  return filtered;
}
