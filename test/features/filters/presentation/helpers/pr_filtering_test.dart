// Test summary:
// - empty filters pass through every PR (no-op)
// - repo facet keeps only matching repos
// - status facet maps draft vs open correctly
// - review-state facet filters by review state
// - CI facet ORs within the facet (failing OR pending)
// - facets combine with AND across facets
// - sort orders by updatedAt descending (most recent first)
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/filters/data/models/pr_filters.dart';
import 'package:turbo_board/features/filters/presentation/helpers/pr_filtering.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';

PrData _pr({
  String repo = 'org/a',
  int number = 1,
  bool isDraft = false,
  PrReviewState review = PrReviewState.needsReview,
  PrCiState ci = PrCiState.passing,
  DateTime? updatedAt,
}) => PrData(
  repo: repo,
  number: number,
  title: 'PR $number',
  author: 'someone',
  isDraft: isDraft,
  reviewState: review,
  ciState: ci,
  updatedAt: updatedAt ?? DateTime(2026, 1, 1),
);

void main() {
  group('applyFilters', () {
    final prs = [
      _pr(number: 1, repo: 'org/a', ci: PrCiState.failing, review: PrReviewState.changesRequested),
      _pr(number: 2, repo: 'org/b', isDraft: true, ci: PrCiState.pending),
      _pr(number: 3, repo: 'org/a', ci: PrCiState.passing, review: PrReviewState.approved),
    ];

    test('empty filters return all PRs', () {
      expect(applyFilters(prs, const PrFilters()).length, 3);
    });

    test('repo facet keeps only matching repos', () {
      expect(applyFilters(prs, const PrFilters(repos: {'org/a'})).map((p) => p.number).toSet(), {1, 3});
    });

    test('status facet distinguishes draft from open', () {
      expect(applyFilters(prs, const PrFilters(statuses: {PrStatus.draft})).map((p) => p.number), [2]);
      expect(applyFilters(prs, const PrFilters(statuses: {PrStatus.open})).map((p) => p.number).toSet(), {1, 3});
    });

    test('review-state facet filters by review state', () {
      expect(applyFilters(prs, const PrFilters(reviewStates: {PrReviewState.approved})).map((p) => p.number), [3]);
    });

    test('CI facet ORs within the facet', () {
      final out = applyFilters(prs, const PrFilters(ciStates: {PrCiState.failing, PrCiState.pending}));
      expect(out.map((p) => p.number).toSet(), {1, 2});
    });

    test('facets combine with AND', () {
      final out = applyFilters(prs, const PrFilters(repos: {'org/a'}, ciStates: {PrCiState.failing}));
      expect(out.map((p) => p.number), [1]);
    });

    test('sorts by updatedAt descending', () {
      final unsorted = [
        _pr(number: 1, updatedAt: DateTime(2026, 1, 1)),
        _pr(number: 2, updatedAt: DateTime(2026, 3, 1)),
        _pr(number: 3, updatedAt: DateTime(2026, 2, 1)),
      ];
      expect(applyFilters(unsorted, const PrFilters()).map((p) => p.number), [2, 3, 1]);
    });
  });
}
