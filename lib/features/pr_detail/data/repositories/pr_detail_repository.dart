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
}

class GithubPrDetailRepository implements PrDetailRepository {
  GithubPrDetailRepository(this._client);

  final GithubApiClient _client;

  @override
  Future<Result<PrDetail>> fetchDetail(String owner, String name, int number) async {
    try {
      final data = await _client.graphql(prDetailQuery, {'owner': owner, 'name': name, 'number': number});
      final pr = data['repository']?['pullRequest'] as Map<String, dynamic>?;
      if (pr == null) return Result.failure('Pull request not found.', StackTrace.current);
      return Result.success(prDetailFromNode(owner, name, pr));
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
}

/// Builds a [PrDetail] from a GraphQL `repository.pullRequest` node.
PrDetail prDetailFromNode(String owner, String name, Map<String, dynamic> pr) {
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
    bodyMarkdown: (pr['body'] as String?) ?? '',
    reviewDecision: _reviewDecisionFrom(pr['reviewDecision'] as String?),
    lastCommit: commitNode == null ? null : _commitFrom(commitNode),
    checks: _checksFrom(commitNode),
    reviewers: _reviewersFrom(pr),
    timeline: _timelineFrom(pr),
  );
}

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

List<PrTimelineEvent> _timelineFrom(Map<String, dynamic> pr) {
  final events = <PrTimelineEvent>[];
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
  for (final raw in ((pr['latestReviews']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>()) {
    final body = (raw['body'] as String?) ?? '';
    final created = DateTime.tryParse((raw['submittedAt'] as String?) ?? '');
    if (body.isEmpty || created == null) continue; // skip empty review bodies
    events.add(
      PrTimelineEvent(
        author: (raw['author']?['login'] as String?) ?? 'unknown',
        bodyMarkdown: body,
        createdAt: created,
        kind: PrEventKind.review,
        reviewState: _reviewerStateFrom(raw['state'] as String?),
      ),
    );
  }
  events.sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
}
