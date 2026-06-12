import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:turbo_core/core.dart';

import '../../../pr_inbox/data/models/pr_data.dart' show PrReviewState;
import '../../../repo_setup/data/services/github_api_client.dart';
import '../models/pr_check.dart';
import '../models/pr_commit.dart';
import '../models/pr_detail.dart';
import '../models/pr_reviewer.dart';
import '../models/pr_timeline_event.dart';
import '../queries/pr_detail_query.dart';
import '../queries/pr_mutations.dart';

abstract interface class PrDetailRepository {
  Future<Result<PrDetail>> fetchDetail(String owner, String name, int number);

  /// Posts a comment to the PR conversation. [subjectId] is the PR node id.
  Future<Result<bool>> addComment(String subjectId, String body);

  /// Submits a PR review. [event] is APPROVE / REQUEST_CHANGES / COMMENT.
  Future<Result<bool>> submitReview(String pullRequestId, String event, String body);

  /// Merges the PR. [mergeMethod] is MERGE / SQUASH / REBASE.
  Future<Result<bool>> mergePullRequest(String pullRequestId, String mergeMethod);

  /// Deletes the PR's head branch. [refId] is the head ref node id.
  Future<Result<bool>> deleteHeadBranch(String refId);
}

class GithubPrDetailRepository implements PrDetailRepository {
  GithubPrDetailRepository(this._client);

  final GithubApiClient _client;

  @override
  Future<Result<PrDetail>> fetchDetail(String owner, String name, int number) async {
    try {
      final data = await _client.graphql(prDetailQuery, {'owner': owner, 'name': name, 'number': number});
      final repoNode = data['repository'] as Map<String, dynamic>?;
      final pr = repoNode?['pullRequest'] as Map<String, dynamic>?;
      if (pr == null) return Result.failure('Pull request not found.', StackTrace.current);
      return Result.success(prDetailFromNode(owner, name, repoNode!, pr));
    } catch (e, stackTrace) {
      log('Failed to fetch PR detail', error: e, stackTrace: stackTrace);
      return Result.failure('Could not load the pull request.', stackTrace);
    }
  }

  @override
  Future<Result<bool>> addComment(String subjectId, String body) async {
    try {
      await _client.graphql(addCommentMutation, {'subjectId': subjectId, 'body': body});
      return Result.success(true);
    } catch (e, stackTrace) {
      log('Failed to post PR comment', error: e, stackTrace: stackTrace);
      return Result.failure('Could not post your comment.', stackTrace);
    }
  }

  @override
  Future<Result<bool>> submitReview(String pullRequestId, String event, String body) async {
    try {
      await _client.graphql(addReviewMutation, {
        'pullRequestId': pullRequestId,
        'event': event,
        'body': body.isEmpty ? null : body,
      });
      return Result.success(true);
    } catch (e, stackTrace) {
      log('Failed to submit PR review', error: e, stackTrace: stackTrace);
      return Result.failure('Could not submit your review.', stackTrace);
    }
  }

  @override
  Future<Result<bool>> mergePullRequest(String pullRequestId, String mergeMethod) async {
    try {
      await _client.graphql(mergePrMutation, {'pullRequestId': pullRequestId, 'method': mergeMethod});
      return Result.success(true);
    } catch (e, stackTrace) {
      log('Failed to merge PR', error: e, stackTrace: stackTrace);
      return Result.failure('Could not merge the pull request.', stackTrace);
    }
  }

  @override
  Future<Result<bool>> deleteHeadBranch(String refId) async {
    try {
      await _client.graphql(deleteRefMutation, {'refId': refId});
      return Result.success(true);
    } catch (e, stackTrace) {
      log('Failed to delete branch', error: e, stackTrace: stackTrace);
      return Result.failure('Could not delete the branch.', stackTrace);
    }
  }
}

/// Builds a [PrDetail] from a GraphQL `repository` node ([repoNode]) and its
/// `pullRequest` child ([pr]). Repo-level fields (merge permission, allowed
/// strategies) live on [repoNode].
PrDetail prDetailFromNode(String owner, String name, Map<String, dynamic> repoNode, Map<String, dynamic> pr) {
  final commitNode =
      ((pr['commits']?['nodes'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?)?['commit']
          as Map<String, dynamic>?;

  return PrDetail(
    repo: '$owner/$name',
    id: pr['id'] as String?,
    number: (pr['number'] as int?) ?? 0,
    title: (pr['title'] as String?) ?? '',
    url: pr['url'] as String?,
    state: _stateFrom(pr['state'] as String?),
    isDraft: (pr['isDraft'] as bool?) ?? false,
    author: (pr['author']?['login'] as String?) ?? 'unknown',
    baseRefName: (pr['baseRefName'] as String?) ?? '',
    headRefName: (pr['headRefName'] as String?) ?? '',
    headRefId: pr['headRef']?['id'] as String?,
    isCrossRepository: (pr['isCrossRepository'] as bool?) ?? false,
    bodyMarkdown: (pr['body'] as String?) ?? '',
    reviewDecision: _reviewDecisionFrom(pr['reviewDecision'] as String?),
    lastCommit: commitNode == null ? null : _commitFrom(commitNode),
    checks: _checksFrom(commitNode),
    reviewers: _reviewersFrom(pr),
    timeline: _timelineFrom(pr),
    canMerge: _canMerge(repoNode['viewerPermission'] as String?),
    mergeable: _mergeableFrom(pr['mergeable'] as String?),
    mergeStateStatus: pr['mergeStateStatus'] as String?,
    mergeCommitAllowed: (repoNode['mergeCommitAllowed'] as bool?) ?? false,
    squashMergeAllowed: (repoNode['squashMergeAllowed'] as bool?) ?? false,
    rebaseMergeAllowed: (repoNode['rebaseMergeAllowed'] as bool?) ?? false,
  );
}

/// WRITE+ on the repo means the viewer may merge.
bool _canMerge(String? perm) => perm == 'ADMIN' || perm == 'MAINTAIN' || perm == 'WRITE';

PrMergeable _mergeableFrom(String? m) => switch (m) {
  'MERGEABLE' => PrMergeable.mergeable,
  'CONFLICTING' => PrMergeable.conflicting,
  _ => PrMergeable.unknown,
};

PrState _stateFrom(String? s) => switch (s) {
  'MERGED' => PrState.merged,
  'CLOSED' => PrState.closed,
  _ => PrState.open,
};

PrReviewState? _reviewDecisionFrom(String? d) => switch (d) {
  'REVIEW_REQUIRED' => PrReviewState.needsReview,
  'CHANGES_REQUESTED' => PrReviewState.changesRequested,
  'APPROVED' => PrReviewState.approved,
  _ => null,
};

PrCommit _commitFrom(Map<String, dynamic> commit) => PrCommit(
  abbreviatedOid: (commit['abbreviatedOid'] as String?) ?? '',
  messageHeadline: (commit['messageHeadline'] as String?) ?? '',
  committedDate: DateTime.tryParse((commit['committedDate'] as String?) ?? ''),
);

List<PrCheck> _checksFrom(Map<String, dynamic>? commit) {
  final nodes = (commit?['statusCheckRollup']?['contexts']?['nodes'] as List<dynamic>?) ?? const [];
  final checks = <PrCheck>[];
  for (final raw in nodes.whereType<Map<String, dynamic>>()) {
    final type = raw['__typename'] as String?;
    if (type == 'CheckRun') {
      checks.add(
        PrCheck(
          name: (raw['name'] as String?) ?? 'check',
          state: _checkRunState(raw['status'] as String?, raw['conclusion'] as String?),
          summary: (raw['conclusion'] as String?)?.toLowerCase(),
        ),
      );
    } else if (type == 'StatusContext') {
      checks.add(
        PrCheck(
          name: (raw['context'] as String?) ?? 'status',
          state: _statusContextState(raw['state'] as String?),
          summary: (raw['state'] as String?)?.toLowerCase(),
        ),
      );
    }
  }
  return checks;
}

PrCheckState _checkRunState(String? status, String? conclusion) {
  if (status != 'COMPLETED') return PrCheckState.pending;
  return switch (conclusion) {
    'SUCCESS' => PrCheckState.success,
    'NEUTRAL' || 'SKIPPED' => PrCheckState.neutral,
    _ => PrCheckState.failure,
  };
}

PrCheckState _statusContextState(String? state) => switch (state) {
  'SUCCESS' => PrCheckState.success,
  'PENDING' || 'EXPECTED' => PrCheckState.pending,
  _ => PrCheckState.failure,
};

PrReviewerState _reviewerStateFrom(String? state) => switch (state) {
  'APPROVED' => PrReviewerState.approved,
  'CHANGES_REQUESTED' => PrReviewerState.changesRequested,
  'COMMENTED' => PrReviewerState.commented,
  _ => PrReviewerState.pending,
};

List<PrReviewer> _reviewersFrom(Map<String, dynamic> pr) {
  final byLogin = <String, PrReviewerState>{};
  // Pending requested reviewers first.
  for (final raw
      in ((pr['reviewRequests']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>()) {
    final reviewer = raw['requestedReviewer'] as Map<String, dynamic>?;
    final login = (reviewer?['login'] ?? reviewer?['name']) as String?;
    if (login != null) byLogin[login] = PrReviewerState.pending;
  }
  // Submitted reviews supersede pending requests.
  for (final raw in ((pr['latestReviews']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>()) {
    final login = raw['author']?['login'] as String?;
    if (login != null) byLogin[login] = _reviewerStateFrom(raw['state'] as String?);
  }
  return [for (final e in byLogin.entries) PrReviewer(login: e.key, state: e.value)];
}

/// Builds the activity timeline (mirrors the design's `timelineFor`): an
/// "opened" event, then issue comments and reviews interleaved in chronological
/// order. A review with a body becomes a comment card; an APPROVED /
/// CHANGES_REQUESTED review also emits a compact state event (so the timeline
/// reads like GitHub's own conversation view).
List<PrTimelineEvent> _timelineFrom(Map<String, dynamic> pr) {
  final events = <PrTimelineEvent>[];

  // PR opened — the first node in the timeline.
  final opened = DateTime.tryParse((pr['createdAt'] as String?) ?? '');
  if (opened != null) {
    events.add(
      PrTimelineEvent(
        author: (pr['author']?['login'] as String?) ?? 'unknown',
        createdAt: opened,
        kind: PrEventKind.opened,
      ),
    );
  }

  for (final raw in ((pr['comments']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>()) {
    final created = DateTime.tryParse((raw['createdAt'] as String?) ?? '');
    if (created == null) continue;
    events.add(
      PrTimelineEvent(
        author: (raw['author']?['login'] as String?) ?? 'unknown',
        bodyMarkdown: (raw['body'] as String?) ?? '',
        createdAt: created,
        kind: PrEventKind.comment,
      ),
    );
  }

  // Use the full review history (not `latestReviews`, which collapses to the
  // latest review per author and silently drops earlier ones — e.g. a
  // CHANGES_REQUESTED review with a comment that gets superseded once the PR is
  // later approved, so its body would never appear in the timeline).
  for (final raw in ((pr['reviews']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>()) {
    final created = DateTime.tryParse((raw['submittedAt'] as String?) ?? '');
    if (created == null) continue;
    final author = (raw['author']?['login'] as String?) ?? 'unknown';
    final state = _reviewerStateFrom(raw['state'] as String?);
    final body = (raw['body'] as String?) ?? '';

    // A review with prose becomes a comment card carrying the review badge.
    if (body.isNotEmpty) {
      events.add(
        PrTimelineEvent(
          author: author,
          bodyMarkdown: body,
          createdAt: created,
          kind: PrEventKind.reviewComment,
          reviewState: state,
        ),
      );
    }
    // Approve / request-changes also drop a compact state event (after the card
    // when both exist, since they share `submittedAt` and the sort is stable).
    if (state == PrReviewerState.approved) {
      events.add(PrTimelineEvent(author: author, createdAt: created, kind: PrEventKind.approved));
    } else if (state == PrReviewerState.changesRequested) {
      events.add(PrTimelineEvent(author: author, createdAt: created, kind: PrEventKind.changesRequested));
    }
  }

  events.addAll(_activityFrom(pr));

  // Stable chronological sort: ties keep insertion order (card before its event).
  final indexed = [for (var i = 0; i < events.length; i++) (i, events[i])];
  indexed.sort((a, b) {
    final byTime = a.$2.createdAt.compareTo(b.$2.createdAt);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Maps GitHub `timelineItems` into compact activity events: commits pushed
/// (consecutive commits by one author collapsed into a single "added N commits"
/// node), review requests, force-pushes, label adds, ready-for-review, title
/// renames, and merge/close/reopen lifecycle events.
List<PrTimelineEvent> _activityFrom(Map<String, dynamic> pr) {
  final nodes = ((pr['timelineItems']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>();
  final events = <PrTimelineEvent>[];

  // Pending run of consecutive commits by the same author.
  String? pendingAuthor;
  int pendingCount = 0;
  DateTime? pendingAt;
  void flushCommits() {
    if (pendingCount == 0 || pendingAt == null) return;
    events.add(
      PrTimelineEvent(
        author: pendingAuthor ?? 'unknown',
        createdAt: pendingAt!,
        kind: PrEventKind.commitsPushed,
        detail: '$pendingCount',
      ),
    );
    pendingAuthor = null;
    pendingCount = 0;
    pendingAt = null;
  }

  String? reviewerName(Map<String, dynamic>? r) => (r?['login'] ?? r?['name']) as String?;
  DateTime? at(Map<String, dynamic> n) => DateTime.tryParse((n['createdAt'] as String?) ?? '');
  String actor(Map<String, dynamic> n) => (n['actor']?['login'] as String?) ?? 'unknown';

  for (final n in nodes) {
    final type = n['__typename'] as String?;
    if (type == 'PullRequestCommit') {
      final commit = n['commit'] as Map<String, dynamic>?;
      final when = DateTime.tryParse((commit?['committedDate'] as String?) ?? '');
      if (when == null) continue;
      final login = (commit?['author']?['user']?['login'] ?? commit?['author']?['name']) as String?;
      if (pendingCount > 0 && login != pendingAuthor) flushCommits();
      pendingAuthor = login;
      pendingCount++;
      pendingAt = when; // last commit in the run carries the timestamp
      continue;
    }
    flushCommits(); // any non-commit ends the current run

    final when = at(n);
    if (when == null) continue;
    final (kind, detail) = switch (type) {
      'ReviewRequestedEvent' => (
        PrEventKind.reviewRequested,
        reviewerName(n['requestedReviewer'] as Map<String, dynamic>?),
      ),
      'ReviewRequestRemovedEvent' => (
        PrEventKind.reviewRequestRemoved,
        reviewerName(n['requestedReviewer'] as Map<String, dynamic>?),
      ),
      'LabeledEvent' => (PrEventKind.labeled, n['label']?['name'] as String?),
      'HeadRefForcePushedEvent' => (PrEventKind.forcePushed, null),
      'MergedEvent' => (PrEventKind.merged, null),
      'ClosedEvent' => (PrEventKind.closed, null),
      'ReopenedEvent' => (PrEventKind.reopened, null),
      'ReadyForReviewEvent' => (PrEventKind.readyForReview, null),
      'RenamedTitleEvent' => (PrEventKind.renamed, n['currentTitle'] as String?),
      _ => (null, null),
    };
    if (kind == null) continue;
    events.add(PrTimelineEvent(author: actor(n), createdAt: when, kind: kind, detail: detail));
  }
  flushCommits();
  return events;
}

/// Offline / test implementation.
class MockPrDetailRepository implements PrDetailRepository {
  const MockPrDetailRepository();

  @override
  Future<Result<PrDetail>> fetchDetail(String owner, String name, int number) async => Result.success(
    PrDetail(
      repo: '$owner/$name',
      number: number,
      title: 'Sample pull request',
      state: PrState.open,
      author: 'octocat',
      baseRefName: 'main',
      headRefName: 'feature',
      bodyMarkdown: 'A sample PR body.',
      canMerge: true,
      mergeable: PrMergeable.mergeable,
      mergeStateStatus: 'CLEAN',
      mergeCommitAllowed: true,
      squashMergeAllowed: true,
      rebaseMergeAllowed: true,
      checks: const [PrCheck(name: 'build', state: PrCheckState.success)],
      reviewers: const [PrReviewer(login: 'octocat', state: PrReviewerState.pending)],
      timeline: [
        PrTimelineEvent(
          author: 'octocat',
          bodyMarkdown: 'Looks good.',
          createdAt: DateTime(2026, 6, 10),
          kind: PrEventKind.comment,
        ),
      ],
    ),
  );

  @override
  Future<Result<bool>> addComment(String subjectId, String body) async => Result.success(true);

  @override
  Future<Result<bool>> submitReview(String pullRequestId, String event, String body) async => Result.success(true);

  @override
  Future<Result<bool>> mergePullRequest(String pullRequestId, String mergeMethod) async => Result.success(true);

  @override
  Future<Result<bool>> deleteHeadBranch(String refId) async => Result.success(true);
}
