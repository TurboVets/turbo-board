// Test summary:
// - needsMyReview excludes my own PRs and drafts; falls back to all when login unknown
// - changesRequested / failingChecks / draft category matching
// - stale honours each threshold (3/5/7/14d)
// - a PR can appear in multiple categories at once
// - needsAttentionCount deduplicates across categories
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/needs_attention/presentation/helpers/triage.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';

final _now = DateTime(2026, 6, 11);

PrData _pr({
  int number = 1,
  String author = 'someone',
  bool isDraft = false,
  PrReviewState review = PrReviewState.needsReview,
  PrCiState ci = PrCiState.passing,
  DateTime? updatedAt,
}) => PrData(
  repo: 'org/a',
  number: number,
  title: 'PR $number',
  author: author,
  isDraft: isDraft,
  reviewState: review,
  ciState: ci,
  updatedAt: updatedAt ?? _now,
);

bool _m(PrData pr, NeedsAttentionCategory c, {String? myLogin, int threshold = 7}) =>
    matchesCategory(pr, c, myLogin: myLogin, now: _now, staleThresholdDays: threshold);

void main() {
  group('needsMyReview', () {
    test('matches another author needing review', () {
      expect(_m(_pr(author: 'alex'), NeedsAttentionCategory.needsMyReview, myLogin: 'sang'), isTrue);
    });
    test('excludes my own PR', () {
      expect(_m(_pr(author: 'sang'), NeedsAttentionCategory.needsMyReview, myLogin: 'sang'), isFalse);
    });
    test('excludes drafts', () {
      expect(_m(_pr(author: 'alex', isDraft: true), NeedsAttentionCategory.needsMyReview, myLogin: 'sang'), isFalse);
    });
    test('falls back to all when login unknown', () {
      expect(_m(_pr(author: 'sang'), NeedsAttentionCategory.needsMyReview, myLogin: null), isTrue);
    });
  });

  test('changesRequested / failingChecks / draft', () {
    expect(_m(_pr(review: PrReviewState.changesRequested), NeedsAttentionCategory.changesRequested), isTrue);
    expect(_m(_pr(ci: PrCiState.failing), NeedsAttentionCategory.failingChecks), isTrue);
    expect(_m(_pr(isDraft: true), NeedsAttentionCategory.draft), isTrue);
  });

  group('stale thresholds', () {
    test('5 days old is stale at 3d/5d but not 7d/14d', () {
      final pr = _pr(updatedAt: _now.subtract(const Duration(days: 5)));
      expect(_m(pr, NeedsAttentionCategory.stale, threshold: 3), isTrue);
      expect(_m(pr, NeedsAttentionCategory.stale, threshold: 5), isTrue);
      expect(_m(pr, NeedsAttentionCategory.stale, threshold: 7), isFalse);
      expect(_m(pr, NeedsAttentionCategory.stale, threshold: 14), isFalse);
    });
  });

  test('categorize puts a PR in every matching category', () {
    final pr = _pr(isDraft: true, ci: PrCiState.failing, updatedAt: _now.subtract(const Duration(days: 10)));
    final groups = categorize([pr], myLogin: 'sang', now: _now, staleThresholdDays: 7);
    expect(groups[NeedsAttentionCategory.draft], hasLength(1));
    expect(groups[NeedsAttentionCategory.failingChecks], hasLength(1));
    expect(groups[NeedsAttentionCategory.stale], hasLength(1));
    expect(groups[NeedsAttentionCategory.needsMyReview], isEmpty); // draft excluded
  });

  test('needsAttentionCount deduplicates across categories', () {
    final multi = _pr(
      number: 1,
      isDraft: true,
      ci: PrCiState.failing,
      updatedAt: _now.subtract(const Duration(days: 10)),
    );
    final clean = _pr(number: 2, author: 'me', review: PrReviewState.approved);
    final count = needsAttentionCount([multi, clean], myLogin: 'me', now: _now, staleThresholdDays: 7);
    expect(count, 1);
  });
}
