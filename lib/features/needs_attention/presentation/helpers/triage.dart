import '../../../pr_inbox/data/models/pr_data.dart';

/// The actionable triage buckets. A PR can land in several at once.
enum NeedsAttentionCategory { needsMyReview, changesRequested, failingChecks, draft, stale }

extension NeedsAttentionCategoryLabel on NeedsAttentionCategory {
  String get label => switch (this) {
    NeedsAttentionCategory.needsMyReview => 'Needs my review',
    NeedsAttentionCategory.changesRequested => 'Changes requested',
    NeedsAttentionCategory.failingChecks => 'Failing checks',
    NeedsAttentionCategory.draft => 'Draft',
    NeedsAttentionCategory.stale => 'Stale',
  };
}

/// Allowed stale thresholds in days (matches the segmented control).
const staleThresholdOptions = <int>[3, 5, 7, 14];

/// True if [pr] belongs in [category]. [myLogin] is the authenticated user's
/// login (for "needs my review"); [now] and [staleThresholdDays] drive staleness.
bool matchesCategory(
  PrData pr,
  NeedsAttentionCategory category, {
  required String? myLogin,
  required DateTime now,
  required int staleThresholdDays,
}) {
  return switch (category) {
    // Someone else's PR awaiting review, not a draft. If we don't know who the
    // user is, fall back to "any PR needing review" rather than hiding work.
    NeedsAttentionCategory.needsMyReview =>
      pr.reviewState == PrReviewState.needsReview && !pr.isDraft && (myLogin == null || pr.author != myLogin),
    NeedsAttentionCategory.changesRequested => pr.reviewState == PrReviewState.changesRequested,
    NeedsAttentionCategory.failingChecks => pr.ciState == PrCiState.failing,
    NeedsAttentionCategory.draft => pr.isDraft,
    NeedsAttentionCategory.stale => now.difference(pr.updatedAt).inDays >= staleThresholdDays,
  };
}

/// Groups [prs] by category. A PR appears under every category it matches.
Map<NeedsAttentionCategory, List<PrData>> categorize(
  List<PrData> prs, {
  required String? myLogin,
  required DateTime now,
  required int staleThresholdDays,
}) {
  final result = {for (final c in NeedsAttentionCategory.values) c: <PrData>[]};
  for (final pr in prs) {
    for (final c in NeedsAttentionCategory.values) {
      if (matchesCategory(pr, c, myLogin: myLogin, now: now, staleThresholdDays: staleThresholdDays)) {
        result[c]!.add(pr);
      }
    }
  }
  return result;
}

/// Deduplicated count of PRs matching at least one category — the nav badge value.
int needsAttentionCount(
  List<PrData> prs, {
  required String? myLogin,
  required DateTime now,
  required int staleThresholdDays,
}) {
  return prs
      .where(
        (pr) => NeedsAttentionCategory.values.any(
          (c) => matchesCategory(pr, c, myLogin: myLogin, now: now, staleThresholdDays: staleThresholdDays),
        ),
      )
      .length;
}
