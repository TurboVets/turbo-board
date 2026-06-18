// lib/features/pr_detail/data/models/pr_detail.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../issue_detail/data/models/issue_detail.dart' show IssueRef;
import '../../../pr_inbox/data/models/pr_data.dart' show PrReviewState;
import 'pr_check.dart';
import 'pr_commit.dart';
import 'pr_reviewer.dart';
import 'pr_timeline_event.dart';

part 'pr_detail.freezed.dart';

enum PrState { open, closed, merged }

/// Whether GitHub can merge the PR without conflicts.
enum PrMergeable { mergeable, conflicting, unknown }

/// A GitHub merge strategy. [graphql] is the `PullRequestMergeMethod` enum value.
enum PrMergeMethod {
  merge('MERGE', 'Create a merge commit'),
  squash('SQUASH', 'Squash and merge'),
  rebase('REBASE', 'Rebase and merge');

  const PrMergeMethod(this.graphql, this.label);
  final String graphql;
  final String label;
}

@freezed
sealed class PrDetail with _$PrDetail {
  const PrDetail._();

  const factory PrDetail({
    required String repo, // "owner/name"
    String? id, // GraphQL node id — needed to post comments / reviews
    required int number,
    required String title,
    String? url, // PR page on github.com

    required PrState state,
    @Default(false) bool isDraft,
    required String author,
    required String baseRefName,
    required String headRefName,
    String? headRefId, // GraphQL ref node id — needed to delete the branch; null once deleted
    @Default(false) bool isCrossRepository, // head branch lives in a fork — can't delete from here
    @Default('') String bodyMarkdown,
    PrReviewState? reviewDecision,
    PrCommit? lastCommit,
    @Default([]) List<PrCheck> checks,
    @Default([]) List<PrReviewer> reviewers,
    @Default([]) List<PrTimelineEvent> timeline,

    // Merge gating — derived from the viewer's repo permission, the repo's
    // allowed merge strategies, and GitHub's mergeability check.
    @Default(false) bool canMerge, // viewer has write+ access
    @Default(PrMergeable.unknown) PrMergeable mergeable,
    String? mergeStateStatus, // GitHub MergeStateStatus: CLEAN, BLOCKED, BEHIND, DIRTY, …
    @Default(false) bool mergeCommitAllowed,
    @Default(false) bool squashMergeAllowed,
    @Default(false) bool rebaseMergeAllowed,
    @Default(<IssueRef>[]) List<IssueRef> linkedIssues,
  }) = _PrDetail;

  String get slug => '$repo#$number';

  /// Merge strategies the repo permits, in GitHub's display order.
  List<PrMergeMethod> get allowedMergeMethods => [
    if (mergeCommitAllowed) PrMergeMethod.merge,
    if (squashMergeAllowed) PrMergeMethod.squash,
    if (rebaseMergeAllowed) PrMergeMethod.rebase,
  ];

  /// The viewer may act on merging this PR (show the button) — open, non-draft,
  /// has write access, and the repo allows at least one strategy. Whether the
  /// button is *enabled* is [isMergeReady].
  bool get canMergeAction => state == PrState.open && !isDraft && canMerge && allowedMergeMethods.isNotEmpty;

  /// All of GitHub's merge requirements are satisfied: no conflicts, and the
  /// branch-protection state is mergeable. BLOCKED (required reviews/checks),
  /// BEHIND (out of date), DIRTY (conflicts), DRAFT and UNKNOWN are not ready.
  /// CLEAN / HAS_HOOKS / UNSTABLE (only non-required checks failing) are.
  bool get isMergeReady =>
      canMergeAction &&
      mergeable == PrMergeable.mergeable &&
      const {'CLEAN', 'HAS_HOOKS', 'UNSTABLE'}.contains(mergeStateStatus);

  /// Offer the "delete branch" action: the PR is done (merged or closed), the
  /// head branch still exists in this repo (not a fork), and the viewer has
  /// write access. After deletion [headRefId] is null on refetch, hiding it.
  bool get canDeleteBranch =>
      (state == PrState.merged || state == PrState.closed) &&
      !isCrossRepository &&
      headRefId != null &&
      headRefName != baseRefName &&
      canMerge;
}
