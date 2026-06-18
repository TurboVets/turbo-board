// lib/features/issue_detail/data/repositories/issue_detail_repository.dart
import 'dart:developer';

import 'package:turbo_core/core.dart';

import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../pr_inbox/data/models/pr_data.dart';
import '../../../repo_setup/data/services/github_api_client.dart';
import '../models/issue_detail.dart';
import '../queries/issue_detail_query.dart';
import '../queries/issue_mutations.dart';

abstract interface class IssueDetailRepository {
  Future<Result<IssueDetail>> fetchDetail(String owner, String name, int number);
  Future<Result<bool>> addComment(String subjectId, String body);
  Future<Result<bool>> closeIssue(String issueId);
  Future<Result<bool>> reopenIssue(String issueId);

  /// Creates a branch from the issue; returns the created branch name.
  Future<Result<String>> createBranch(String issueId, String oid, String name);
}

class GithubIssueDetailRepository implements IssueDetailRepository {
  GithubIssueDetailRepository(this._client);

  final GithubApiClient _client;

  @override
  Future<Result<IssueDetail>> fetchDetail(String owner, String name, int number) async {
    try {
      final data = await _client.graphql(issueDetailQuery, {'owner': owner, 'name': name, 'number': number});
      final repoNode = data['repository'] as Map<String, dynamic>?;
      if (repoNode?['issue'] == null) return Result.failure('Issue not found.', StackTrace.current);
      return Result.success(issueDetailFromNode(owner, name, repoNode!));
    } catch (e, stackTrace) {
      log('Failed to fetch issue detail', error: e, stackTrace: stackTrace);
      return Result.failure('Could not load the issue.', stackTrace);
    }
  }

  @override
  Future<Result<bool>> addComment(String subjectId, String body) =>
      _mutate(addIssueCommentMutation, {'subjectId': subjectId, 'body': body}, 'Could not post your comment.');

  @override
  Future<Result<bool>> closeIssue(String issueId) =>
      _mutate(closeIssueMutation, {'issueId': issueId}, 'Could not close the issue.');

  @override
  Future<Result<bool>> reopenIssue(String issueId) =>
      _mutate(reopenIssueMutation, {'issueId': issueId}, 'Could not reopen the issue.');

  @override
  Future<Result<String>> createBranch(String issueId, String oid, String name) async {
    try {
      final data = await _client.graphql(createLinkedBranchMutation, {'issueId': issueId, 'oid': oid, 'name': name});
      final created = data['createLinkedBranch']?['linkedBranch']?['ref']?['name'] as String?;
      return Result.success(created ?? name);
    } catch (e, stackTrace) {
      log('Failed to create branch', error: e, stackTrace: stackTrace);
      return Result.failure('Could not create the branch.', stackTrace);
    }
  }

  Future<Result<bool>> _mutate(String mutation, Map<String, dynamic> vars, String failure) async {
    try {
      await _client.graphql(mutation, vars);
      return Result.success(true);
    } catch (e, stackTrace) {
      log(failure, error: e, stackTrace: stackTrace);
      return Result.failure(failure, stackTrace);
    }
  }
}

/// Pure node -> model transform. IO-free so it unit-tests with fixture JSON.
IssueDetail issueDetailFromNode(String owner, String name, Map<String, dynamic> repoNode) {
  final issue = repoNode['issue'] as Map<String, dynamic>;
  final fields = _projectFields(issue);
  return IssueDetail(
    repo: '$owner/$name',
    id: issue['id'] as String?,
    number: (issue['number'] as num?)?.toInt() ?? 0,
    title: (issue['title'] as String?) ?? '',
    url: issue['url'] as String?,
    state: (issue['state'] as String?) == 'CLOSED' ? IssueState.closed : IssueState.open,
    author: (issue['author']?['login'] as String?) ?? 'unknown',
    createdAt: DateTime.tryParse((issue['createdAt'] as String?) ?? ''),
    bodyMarkdown: (issue['body'] as String?) ?? '',
    commentCount: (issue['comments']?['totalCount'] as num?)?.toInt() ?? 0,
    assignees: _logins(issue['assignees']),
    participants: _logins(issue['participants']),
    labels: ((issue['labels']?['nodes'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((l) => IssueLabel(name: (l['name'] as String?) ?? '', colorHex: (l['color'] as String?) ?? '6e6e76'))
        .toList(),
    milestone: issue['milestone']?['title'] as String?,
    status: fields.status,
    priority: fields.priority,
    sprint: fields.sprint,
    points: fields.points,
    parent: _parentFrom(issue['parent'] as Map<String, dynamic>?),
    subIssues: _subIssuesFrom(issue),
    linkedPrs: _linkedPrsFrom(issue),
    timeline: _timelineFrom(issue),
    viewerCanUpdate: (issue['viewerCanUpdate'] as bool?) ?? false,
    repoDefaultBranchOid: repoNode['defaultBranchRef']?['target']?['oid'] as String?,
  );
}

List<String> _logins(dynamic conn) => ((conn?['nodes'] as List<dynamic>?) ?? const [])
    .whereType<Map<String, dynamic>>()
    .map((n) => n['login'] as String?)
    .whereType<String>()
    .toList();

typedef _Fields = ({IssueStatus? status, IssuePriority? priority, String? sprint, int? points});

_Fields _projectFields(Map<String, dynamic> issue) {
  IssueStatus? status;
  IssuePriority? priority;
  String? sprint;
  int? points;
  final items = (issue['projectItems']?['nodes'] as List<dynamic>?) ?? const [];
  for (final item in items.whereType<Map<String, dynamic>>()) {
    for (final raw
        in ((item['fieldValues']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>()) {
      final field = (raw['field']?['name'] as String?)?.toLowerCase() ?? '';
      switch (raw['__typename']) {
        case 'ProjectV2ItemFieldSingleSelectValue':
          final v = raw['name'] as String?;
          if (field == 'status') status = _statusFrom(v);
          if (field == 'priority') priority = _priorityFrom(v);
        case 'ProjectV2ItemFieldNumberValue':
          if (field == 'complexity') points = (raw['number'] as num?)?.round();
        case 'ProjectV2ItemFieldIterationValue':
          if (field == 'sprint') sprint = raw['title'] as String?;
      }
    }
  }
  return (status: status, priority: priority, sprint: sprint, points: points);
}

IssueRef? _parentFrom(Map<String, dynamic>? p) => p == null
    ? null
    : IssueRef(
        repo: (p['repository']?['nameWithOwner'] as String?) ?? '',
        number: (p['number'] as num?)?.toInt() ?? 0,
        title: (p['title'] as String?) ?? '',
        status: (p['state'] as String?) == 'CLOSED' ? IssueStatus.done : null,
      );

List<SubIssue> _subIssuesFrom(Map<String, dynamic> issue) =>
    ((issue['subIssues']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>().map((s) {
      final closed = (s['state'] as String?) == 'CLOSED';
      return SubIssue(
        number: (s['number'] as num?)?.toInt() ?? 0,
        title: (s['title'] as String?) ?? '',
        status: closed ? IssueStatus.done : IssueStatus.inProgress,
        done: closed,
        assignee:
            (s['assignees']?['nodes'] as List<dynamic>?)?.whereType<Map<String, dynamic>>().firstOrNull?['login']
                as String?,
      );
    }).toList();

List<LinkedPr> _linkedPrsFrom(Map<String, dynamic> issue) =>
    ((issue['closedByPullRequestsReferences']?['nodes'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((pr) {
          final rollup =
              (pr['commits']?['nodes'] as List<dynamic>?)
                      ?.whereType<Map<String, dynamic>>()
                      .firstOrNull?['commit']?['statusCheckRollup']?['state']
                  as String?;
          final draft = (pr['isDraft'] as bool?) ?? false;
          return LinkedPr(
            owner: (pr['repository']?['owner']?['login'] as String?) ?? '',
            repo: (pr['repository']?['name'] as String?) ?? '',
            number: (pr['number'] as num?)?.toInt() ?? 0,
            title: (pr['title'] as String?) ?? '',
            isDraft: draft,
            ciState: _ciFrom(rollup),
            reviewState: _reviewFrom(pr['reviewDecision'] as String?),
            mergeState: _mergeFrom(pr['state'] as String?, draft),
          );
        })
        .toList();

PrCiState _ciFrom(String? s) => switch (s) {
  'SUCCESS' => PrCiState.passing,
  'FAILURE' || 'ERROR' => PrCiState.failing,
  _ => PrCiState.pending,
};

PrReviewState _reviewFrom(String? d) => switch (d) {
  'APPROVED' => PrReviewState.approved,
  'CHANGES_REQUESTED' => PrReviewState.changesRequested,
  'REVIEW_REQUIRED' => PrReviewState.needsReview,
  _ => PrReviewState.waitingOnAuthor,
};

PrLinkMergeState _mergeFrom(String? state, bool draft) {
  if (draft) return PrLinkMergeState.draft;
  return switch (state) {
    'MERGED' => PrLinkMergeState.merged,
    'CLOSED' => PrLinkMergeState.closed,
    _ => PrLinkMergeState.open,
  };
}

IssueStatus? _statusFrom(String? name) {
  final n = name?.trim().toLowerCase();
  return switch (n) {
    'not started' || 'backlog' || 'todo' || 'to do' => IssueStatus.notStarted,
    'in progress' || 'doing' => IssueStatus.inProgress,
    'in review' || 'review' => IssueStatus.inReview,
    'triage' || 'blocked' => IssueStatus.triage,
    'done' || 'closed' || 'shipped' => IssueStatus.done,
    'cancelled' || 'canceled' => IssueStatus.cancelled,
    _ => null,
  };
}

IssuePriority? _priorityFrom(String? name) {
  final n = name?.trim().toLowerCase();
  return switch (n) {
    'p0' || 'critical' || 'urgent' => IssuePriority.p0,
    'p1' || 'high' => IssuePriority.p1,
    'p2' || 'medium' => IssuePriority.p2,
    'p3' || 'low' => IssuePriority.p3,
    _ => null,
  };
}

/// Builds the activity timeline: a synthesized "opened" event from the issue's
/// createdAt, then comments and lifecycle events in chronological order.
List<IssueTimelineEvent> _timelineFrom(Map<String, dynamic> issue) {
  final events = <IssueTimelineEvent>[];
  final opened = DateTime.tryParse((issue['createdAt'] as String?) ?? '');
  if (opened != null) {
    events.add(
      IssueTimelineEvent(
        author: (issue['author']?['login'] as String?) ?? 'unknown',
        createdAt: opened,
        kind: IssueEventKind.opened,
      ),
    );
  }
  for (final n
      in ((issue['timelineItems']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>()) {
    final when = DateTime.tryParse((n['createdAt'] as String?) ?? '');
    if (when == null) continue;
    final actor = (n['actor']?['login'] ?? n['author']?['login']) as String? ?? 'unknown';
    final (IssueEventKind kind, String body, String? detail) = switch (n['__typename']) {
      'IssueComment' => (IssueEventKind.comment, (n['body'] as String?) ?? '', null),
      'ClosedEvent' => (IssueEventKind.closed, '', null),
      'ReopenedEvent' => (IssueEventKind.reopened, '', null),
      'LabeledEvent' => (IssueEventKind.labeled, '', n['label']?['name'] as String?),
      'AssignedEvent' => (IssueEventKind.assigned, '', n['assignee']?['login'] as String?),
      'UnassignedEvent' => (IssueEventKind.unassigned, '', n['assignee']?['login'] as String?),
      'CrossReferencedEvent' => (IssueEventKind.crossReferenced, '', (n['source']?['number'] as num?)?.toString()),
      'RenamedTitleEvent' => (IssueEventKind.renamed, '', n['currentTitle'] as String?),
      _ => (IssueEventKind.comment, '', null),
    };
    events.add(IssueTimelineEvent(author: actor, createdAt: when, kind: kind, bodyMarkdown: body, detail: detail));
  }
  final indexed = [for (var i = 0; i < events.length; i++) (i, events[i])];
  indexed.sort((a, b) {
    final t = a.$2.createdAt.compareTo(b.$2.createdAt);
    return t != 0 ? t : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// In-memory issue seeded from `Issue Detail.dc.html`, for tests and tokenless runs.
class MockIssueDetailRepository implements IssueDetailRepository {
  const MockIssueDetailRepository();

  @override
  Future<Result<IssueDetail>> fetchDetail(String owner, String name, int number) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return Result.success(sampleIssueDetail);
  }

  @override
  Future<Result<bool>> addComment(String subjectId, String body) async => Result.success(true);
  @override
  Future<Result<bool>> closeIssue(String issueId) async => Result.success(true);
  @override
  Future<Result<bool>> reopenIssue(String issueId) async => Result.success(true);
  @override
  Future<Result<String>> createBranch(String issueId, String oid, String name) async => Result.success(name);
}

/// Sample from `Issue Detail.dc.html` (auth-rotation issue #155).
final IssueDetail sampleIssueDetail = IssueDetail(
  repo: 'turbovets/web-portal',
  id: 'I_sample',
  number: 155,
  title: 'Rotate API keys per request before RSC migration',
  url: 'https://github.com/turbovets/web-portal/issues/155',
  state: IssueState.open,
  author: 'apatel-tv',
  createdAt: DateTime.utc(2026, 6, 10, 14, 30),
  bodyMarkdown:
      'The portal still reads API keys from the legacy `env.AUTH_KEY` singleton. '
      'Before the RSC migration we need to rotate keys per-request and move auth into a server context.\n\n'
      '### Acceptance criteria\n'
      '- [x] Audit all `env.AUTH_KEY` reads\n'
      '- [x] Add per-request `rotateKey`\n'
      '- [ ] Migrate auth into server context\n'
      '- [ ] Remove the legacy singleton\n',
  commentCount: 4,
  assignees: const ['apatel-tv', 'snguyen-tv'],
  labels: const [
    IssueLabel(name: 'bug', colorHex: 'e94a5f'),
    IssueLabel(name: 'security', colorHex: 'ffb000'),
  ],
  participants: const ['apatel-tv', 'snguyen-tv', 'tromero-tv'],
  status: IssueStatus.inProgress,
  priority: IssuePriority.p1,
  sprint: 'Sprint 24',
  points: 5,
  milestone: 'v3.0',
  parent: const IssueRef(
    repo: 'turbovets/web-portal',
    number: 99,
    title: 'RSC migration epic',
    status: IssueStatus.inProgress,
  ),
  subIssues: const [
    SubIssue(
      number: 156,
      title: 'Bind key to request context',
      status: IssueStatus.done,
      done: true,
      assignee: 'snguyen-tv',
    ),
    SubIssue(
      number: 157,
      title: 'KMS issue per tenant',
      status: IssueStatus.inProgress,
      done: false,
      assignee: 'apatel-tv',
    ),
    SubIssue(number: 158, title: 'Remove env.AUTH_KEY singleton', status: IssueStatus.notStarted, done: false),
  ],
  linkedPrs: const [
    LinkedPr(
      owner: 'turbovets',
      repo: 'web-portal',
      number: 482,
      title: 'Add per-request key rotation',
      isDraft: false,
      ciState: PrCiState.passing,
      reviewState: PrReviewState.approved,
      mergeState: PrLinkMergeState.open,
    ),
    LinkedPr(
      owner: 'turbovets',
      repo: 'web-portal',
      number: 155,
      title: 'WIP: server auth context',
      isDraft: true,
      ciState: PrCiState.failing,
      reviewState: PrReviewState.changesRequested,
      mergeState: PrLinkMergeState.draft,
    ),
  ],
  timeline: [
    IssueTimelineEvent(author: 'apatel-tv', createdAt: DateTime.utc(2026, 6, 10, 14, 30), kind: IssueEventKind.opened),
    IssueTimelineEvent(
      author: 'snguyen-tv',
      createdAt: DateTime.utc(2026, 6, 11, 9),
      kind: IssueEventKind.comment,
      bodyMarkdown: 'Started on the request-context binding — PR up shortly.',
    ),
    IssueTimelineEvent(
      author: 'tromero-tv',
      createdAt: DateTime.utc(2026, 6, 12, 16),
      kind: IssueEventKind.labeled,
      detail: 'security',
    ),
  ],
  viewerCanUpdate: true,
  repoDefaultBranchOid: 'deadbeefcafe',
);
