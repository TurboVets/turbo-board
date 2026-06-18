# Issue Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A ProjectV2-enriched GitHub Issue Detail drawer — markdown body, sub-issues, linked PRs, activity timeline + comment composer, project-field sidebar, AI TL;DR + next-action — reached at `/issue/:owner/:repo/:number`, mirroring the shipped PR Detail. Interactive: comment, close/reopen, create-branch-from-issue, open-in-GitHub-Desktop.

**Architecture:** New feature `lib/features/issue_detail/` (data/presentation split) mirroring `pr_detail`. A pure `issueDetailFromNode` mapper turns the GraphQL issue node into `IssueDetail`; repository (interface + Github + Mock) returns `Result`; providers expose the detail future + a composer + two on-demand AI controllers. The drawer screen reuses the PR Detail scrim/slide presentation. AI features extend the existing `ai` feature. Wired from the Lead Cockpit and PR Detail cross-link now; the Projects Board card-tap rewire is a deferred integration step (board feature lives on a separate branch).

**Tech Stack:** Flutter, Riverpod (+riverpod_annotation/codegen), Freezed, GoRouter, flutter_hooks, mockito, turbo_core `Result`, turbo_ui Tether tokens, url_launcher.

## Global Constraints

- `dart format --line-length 120 --set-exit-if-changed .` must pass (CI rejects unformatted).
- `dart analyze` clean; `flutter test` green.
- Depend on `turbo_core` + `turbo_ui` only; no mobile-only plugins; no `dart:io` in shared paths.
- Freezed `sealed class` models with `fromJson` where they round-trip; `@freezed`. Never edit `*.freezed.dart`/`*.g.dart`/`*.mocks.dart` by hand — regenerate with `dart run build_runner build -d`.
- Riverpod: `@Riverpod(keepAlive: true)` for repos/global; lowercase `@riverpod` for autodispose. On-demand AI controllers default state `null` (= not requested), mirroring `PrSummaryController`.
- Errors caught only in the repo layer; surfaced above as `Result` (`turbo_core`).
- Tether tokens from `lib/shared/ui/theme/tb_tokens.dart` (`TbColors`, `TbSignal`); text via `tb_text.dart` (`TbText`); badges/dots/avatars via `lib/shared/ui/widgets/tb_badge.dart` (`TbBadge`, `TbSignalDot`, `TbAvatarTile`). `TbSignal` values: `ok` (green), `warn` (amber), `bad` (red), `info` (blue), `gray`.
- `IssueStatus` (`notStarted, inProgress, inReview, triage, done, cancelled`) and `IssuePriority` (`p0..p3`) come from `lib/features/lead_cockpit/data/models/cockpit_data.dart`. `PrCiState` (`passing, pending, failing`), `PrReviewState` (`needsReview, changesRequested, approved, waitingOnAuthor`), `PrMergeState` (`mergeable, conflicting, unknown`) come from `lib/features/pr_inbox/data/models/pr_data.dart` — **reuse these for `LinkedPr`** (all already on `main`; do not import from `projects_board`, which is not on this branch).
- Each test file starts with a test-summary comment listing its cases (CLAUDE.md).
- Conventional Commits; end commit bodies with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- `GithubApiClient.graphql(String query, Map<String,dynamic> variables) → Future<Map<String,dynamic>>`.
- Drawer chrome decision: **copy** the scrim/slide/`_DrawerPanel` pattern from `pr_detail_screen.dart` privately into `issue_detail_screen.dart` (do NOT refactor PR Detail in this branch — keeps cross-feature churn to the cross-link only). Shared extraction is a future cleanup.

---

### Task 1: Issue Detail data models

**Files:**
- Create: `lib/features/issue_detail/data/models/issue_detail.dart`
- Test: `test/features/issue_detail/data/models/issue_detail_test.dart`

**Interfaces:**
- Consumes: `IssueStatus`, `IssuePriority` (cockpit); `PrCiState`, `PrReviewState`, `PrMergeState` (pr_data).
- Produces: `IssueState`, `IssueLabel`, `IssueRef`, `SubIssue`, `LinkedPr`, `IssueEventKind`, `IssueTimelineEvent`, `IssueDetail`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/issue_detail/data/models/issue_detail_test.dart
//
// Test summary:
// - IssueDetail round-trips through JSON with project fields, sub-issues, linked PRs.
// - subDone/subTotal/hasSubIssues derive from subIssues.
// - isClosed reflects state.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/issue_detail/data/models/issue_detail.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';

void main() {
  final detail = IssueDetail(
    repo: 'turbovets/web-portal',
    id: 'I_123',
    number: 155,
    title: 'Rotate API keys per request',
    url: 'https://github.com/turbovets/web-portal/issues/155',
    state: IssueState.open,
    author: 'apatel-tv',
    createdAt: DateTime.utc(2026, 6, 10),
    bodyMarkdown: 'Body',
    commentCount: 3,
    assignees: const ['apatel-tv'],
    labels: const [IssueLabel(name: 'bug', colorHex: 'e94a5f')],
    participants: const ['apatel-tv', 'snguyen-tv'],
    status: IssueStatus.inProgress,
    priority: IssuePriority.p1,
    sprint: 'Sprint 24',
    points: 5,
    milestone: 'v3',
    parent: const IssueRef(repo: 'turbovets/web-portal', number: 99, title: 'RSC migration epic'),
    subIssues: const [
      SubIssue(number: 156, title: 'Bind ctx', status: IssueStatus.done, done: true, assignee: 'snguyen-tv'),
      SubIssue(number: 157, title: 'KMS issue', status: IssueStatus.inProgress, done: false),
    ],
    linkedPrs: const [
      LinkedPr(
        owner: 'turbovets', repo: 'web-portal', number: 482, title: 'WIP', isDraft: true,
        ciState: PrCiState.failing, reviewState: PrReviewState.changesRequested, mergeState: PrLinkMergeState.open,
      ),
    ],
    timeline: [IssueTimelineEvent(author: 'apatel-tv', createdAt: DateTime.utc(2026, 6, 10), kind: IssueEventKind.opened)],
    viewerCanUpdate: true,
    repoDefaultBranchOid: 'abc123',
  );

  test('IssueDetail round-trips through JSON', () {
    expect(IssueDetail.fromJson(detail.toJson()), detail);
  });

  test('sub-issue progress + state getters', () {
    expect(detail.subDone, 1);
    expect(detail.subTotal, 2);
    expect(detail.hasSubIssues, isTrue);
    expect(detail.isClosed, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/issue_detail/data/models/issue_detail_test.dart`
Expected: FAIL — `issue_detail.dart` does not exist.

- [ ] **Step 3: Write the model file**

```dart
// lib/features/issue_detail/data/models/issue_detail.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../pr_inbox/data/models/pr_data.dart';

part 'issue_detail.freezed.dart';
part 'issue_detail.g.dart';

enum IssueState { open, closed }

/// Merge state of a linked PR, for the third dot in the Linked PRs card.
enum PrLinkMergeState { open, merged, closed, draft }

/// Kinds of activity rendered in the issue timeline.
enum IssueEventKind { opened, comment, closed, reopened, labeled, assigned, unassigned, crossReferenced, renamed }

@freezed
sealed class IssueLabel with _$IssueLabel {
  const factory IssueLabel({required String name, required String colorHex}) = _IssueLabel;
  factory IssueLabel.fromJson(Map<String, dynamic> json) => _$IssueLabelFromJson(json);
}

/// A reference to another issue (parent epic / relationship row).
@freezed
sealed class IssueRef with _$IssueRef {
  const factory IssueRef({
    required String repo, // "owner/name"
    required int number,
    required String title,
    IssueStatus? status,
  }) = _IssueRef;
  factory IssueRef.fromJson(Map<String, dynamic> json) => _$IssueRefFromJson(json);
}

@freezed
sealed class SubIssue with _$SubIssue {
  const factory SubIssue({
    required int number,
    required String title,
    required IssueStatus status,
    @Default(false) bool done,
    String? assignee,
  }) = _SubIssue;
  factory SubIssue.fromJson(Map<String, dynamic> json) => _$SubIssueFromJson(json);
}

@freezed
sealed class LinkedPr with _$LinkedPr {
  const factory LinkedPr({
    required String owner,
    required String repo,
    required int number,
    required String title,
    @Default(false) bool isDraft,
    required PrCiState ciState,
    required PrReviewState reviewState,
    @Default(PrLinkMergeState.open) PrLinkMergeState mergeState,
  }) = _LinkedPr;
  factory LinkedPr.fromJson(Map<String, dynamic> json) => _$LinkedPrFromJson(json);
}

@freezed
sealed class IssueTimelineEvent with _$IssueTimelineEvent {
  const factory IssueTimelineEvent({
    required String author,
    required DateTime createdAt,
    required IssueEventKind kind,
    @Default('') String bodyMarkdown,
    String? detail,
  }) = _IssueTimelineEvent;
  factory IssueTimelineEvent.fromJson(Map<String, dynamic> json) => _$IssueTimelineEventFromJson(json);
}

@freezed
sealed class IssueDetail with _$IssueDetail {
  const IssueDetail._();

  const factory IssueDetail({
    required String repo, // "owner/name"
    String? id, // GraphQL node id — needed for mutations
    required int number,
    required String title,
    String? url,
    required IssueState state,
    required String author,
    DateTime? createdAt,
    @Default('') String bodyMarkdown,
    @Default(0) int commentCount,
    @Default(<String>[]) List<String> assignees,
    @Default(<IssueLabel>[]) List<IssueLabel> labels,
    @Default(<String>[]) List<String> participants,
    IssueStatus? status,
    IssuePriority? priority,
    String? sprint,
    int? points,
    String? milestone,
    IssueRef? parent,
    @Default(<SubIssue>[]) List<SubIssue> subIssues,
    @Default(<LinkedPr>[]) List<LinkedPr> linkedPrs,
    @Default(<IssueTimelineEvent>[]) List<IssueTimelineEvent> timeline,
    @Default(false) bool viewerCanUpdate,
    String? repoDefaultBranchOid,
  }) = _IssueDetail;

  factory IssueDetail.fromJson(Map<String, dynamic> json) => _$IssueDetailFromJson(json);

  String get slug => '$repo#$number';
  int get subDone => subIssues.where((s) => s.done).length;
  int get subTotal => subIssues.length;
  bool get hasSubIssues => subTotal > 0;
  bool get isClosed => state == IssueState.closed;
}
```

- [ ] **Step 4: Generate code**

Run: `dart run build_runner build -d`
Expected: creates `issue_detail.freezed.dart` + `issue_detail.g.dart`, no errors.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/issue_detail/data/models/issue_detail_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/issue_detail/data/models/issue_detail.dart test/features/issue_detail/data/models/issue_detail_test.dart
git commit -m "feat(issue-detail): data models"
```

---

### Task 2: GraphQL query + mutations

**Files:**
- Create: `lib/features/issue_detail/data/queries/issue_detail_query.dart`
- Create: `lib/features/issue_detail/data/queries/issue_mutations.dart`
- Test: `test/features/issue_detail/data/queries/issue_queries_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/issue_detail/data/queries/issue_queries_test.dart
//
// Test summary:
// - issueDetailQuery selects issue identity, body, project fields, sub-issues, linked PRs, timeline, viewerCanUpdate.
// - mutation strings cover addComment, closeIssue, reopenIssue, createLinkedBranch.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/issue_detail/data/queries/issue_detail_query.dart';
import 'package:turbo_board/features/issue_detail/data/queries/issue_mutations.dart';

void main() {
  test('issueDetailQuery covers the fields the mapper reads', () {
    for (final fragment in [
      'issue(number: \$number)', 'viewerCanUpdate', 'subIssuesSummary', 'subIssues(',
      'closedByPullRequestsReferences', 'projectItems', 'timelineItems', 'defaultBranchRef',
    ]) {
      expect(issueDetailQuery, contains(fragment), reason: 'missing $fragment');
    }
  });

  test('mutations cover comment/close/reopen/branch', () {
    expect(addIssueCommentMutation, contains('addComment'));
    expect(closeIssueMutation, contains('closeIssue'));
    expect(reopenIssueMutation, contains('reopenIssue'));
    expect(createLinkedBranchMutation, contains('createLinkedBranch'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/issue_detail/data/queries/issue_queries_test.dart`
Expected: FAIL — query files missing.

- [ ] **Step 3: Write `issue_detail_query.dart`**

```dart
// lib/features/issue_detail/data/queries/issue_detail_query.dart

/// Fetches one issue's detail by owner/name/number, enriched with ProjectV2 fields.
const String issueDetailQuery = r'''
query IssueDetail($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    defaultBranchRef { target { oid } }
    issue(number: $number) {
      id number title url state body createdAt viewerCanUpdate
      author { login }
      labels(first: 20) { nodes { name color } }
      assignees(first: 10) { nodes { login } }
      participants(first: 10) { nodes { login } }
      milestone { title }
      comments(first: 50) { totalCount nodes { author { login } body createdAt } }
      parent { number title state repository { nameWithOwner } }
      subIssuesSummary { total completed }
      subIssues(first: 50) {
        nodes { number title state assignees(first: 1) { nodes { login } } }
      }
      closedByPullRequestsReferences(first: 10, includeClosedPrs: true) {
        nodes {
          number title isDraft state url reviewDecision
          repository { name owner { login } }
          commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
        }
      }
      projectItems(first: 5) {
        nodes {
          fieldValues(first: 20) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2FieldCommon { name } } }
              ... on ProjectV2ItemFieldNumberValue { number field { ... on ProjectV2FieldCommon { name } } }
              ... on ProjectV2ItemFieldIterationValue { title field { ... on ProjectV2FieldCommon { name } } }
            }
          }
        }
      }
      timelineItems(
        first: 60
        itemTypes: [ISSUE_COMMENT, CLOSED_EVENT, REOPENED_EVENT, LABELED_EVENT, ASSIGNED_EVENT, UNASSIGNED_EVENT, CROSS_REFERENCED_EVENT, RENAMED_TITLE_EVENT]
      ) {
        nodes {
          __typename
          ... on IssueComment { createdAt author { login } body }
          ... on ClosedEvent { createdAt actor { login } }
          ... on ReopenedEvent { createdAt actor { login } }
          ... on LabeledEvent { createdAt actor { login } label { name } }
          ... on AssignedEvent { createdAt actor { login } assignee { ... on User { login } } }
          ... on UnassignedEvent { createdAt actor { login } assignee { ... on User { login } } }
          ... on CrossReferencedEvent { createdAt actor { login } source { ... on PullRequest { number } ... on Issue { number } } }
          ... on RenamedTitleEvent { createdAt actor { login } currentTitle }
        }
      }
    }
  }
}
''';
```

- [ ] **Step 4: Write `issue_mutations.dart`**

```dart
// lib/features/issue_detail/data/queries/issue_mutations.dart

/// Posts a comment to the issue conversation. [subjectId] is the issue node id.
const String addIssueCommentMutation = r'''
mutation AddIssueComment($subjectId: ID!, $body: String!) {
  addComment(input: {subjectId: $subjectId, body: $body}) { clientMutationId }
}
''';

/// Closes an issue as completed. [issueId] is the issue node id.
const String closeIssueMutation = r'''
mutation CloseIssue($issueId: ID!) {
  closeIssue(input: {issueId: $issueId, stateReason: COMPLETED}) { issue { state } }
}
''';

/// Reopens a closed issue.
const String reopenIssueMutation = r'''
mutation ReopenIssue($issueId: ID!) {
  reopenIssue(input: {issueId: $issueId}) { issue { state } }
}
''';

/// Creates a branch linked to the issue. [oid] is the base commit (repo default
/// branch head); [name] the new branch name.
const String createLinkedBranchMutation = r'''
mutation CreateLinkedBranch($issueId: ID!, $oid: GitObjectID!, $name: String!) {
  createLinkedBranch(input: {issueId: $issueId, oid: $oid, name: $name}) {
    linkedBranch { ref { name } }
  }
}
''';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/issue_detail/data/queries/issue_queries_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/issue_detail/data/queries test/features/issue_detail/data/queries
git commit -m "feat(issue-detail): GraphQL detail query + mutations"
```

---

### Task 3: Repository + node mapper + mock sample

**Files:**
- Create: `lib/features/issue_detail/data/repositories/issue_detail_repository.dart`
- Test: `test/features/issue_detail/data/repositories/issue_detail_repository_test.dart`

**Interfaces:**
- Consumes: `GithubApiClient`, `issueDetailQuery`, the mutation strings, `IssueDetail` & friends, cockpit/pr enums, turbo_core `Result`.
- Produces: `IssueDetailRepository` (interface), `GithubIssueDetailRepository`, `MockIssueDetailRepository`, top-level `issueDetailFromNode(...)`, and `IssueDetail get sampleIssueDetail`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/issue_detail/data/repositories/issue_detail_repository_test.dart
//
// Test summary:
// - issueDetailFromNode parses identity, body, labels, assignees, milestone, viewerCanUpdate.
// - parses ProjectV2 fields (Status/Priority/Sprint/Complexity) by field name.
// - parses sub-issues (state -> IssueStatus, done when CLOSED) and the parent epic.
// - parses linked PRs: CI rollup -> PrCiState, reviewDecision -> PrReviewState, merge/draft state.
// - builds a chronological timeline (opened first, then comments/events).
// - MockIssueDetailRepository returns sampleIssueDetail; mutations return success.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/issue_detail/data/models/issue_detail.dart';
import 'package:turbo_board/features/issue_detail/data/repositories/issue_detail_repository.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';

Map<String, dynamic> repoNode() => {
  'defaultBranchRef': {'target': {'oid': 'base-oid'}},
  'issue': {
    'id': 'I_1', 'number': 155, 'title': 'Rotate keys',
    'url': 'https://github.com/o/r/issues/155', 'state': 'OPEN', 'body': 'Body text',
    'createdAt': '2026-06-10T00:00:00Z', 'viewerCanUpdate': true,
    'author': {'login': 'apatel-tv'},
    'labels': {'nodes': [{'name': 'bug', 'color': 'e94a5f'}]},
    'assignees': {'nodes': [{'login': 'apatel-tv'}]},
    'participants': {'nodes': [{'login': 'apatel-tv'}, {'login': 'snguyen-tv'}]},
    'milestone': {'title': 'v3'},
    'comments': {'totalCount': 2, 'nodes': [
      {'author': {'login': 'snguyen-tv'}, 'body': 'On it', 'createdAt': '2026-06-11T00:00:00Z'},
    ]},
    'parent': {'number': 99, 'title': 'RSC epic', 'state': 'OPEN', 'repository': {'nameWithOwner': 'o/r'}},
    'subIssuesSummary': {'total': 2, 'completed': 1},
    'subIssues': {'nodes': [
      {'number': 156, 'title': 'Bind ctx', 'state': 'CLOSED', 'assignees': {'nodes': [{'login': 'snguyen-tv'}]}},
      {'number': 157, 'title': 'KMS', 'state': 'OPEN', 'assignees': {'nodes': []}},
    ]},
    'closedByPullRequestsReferences': {'nodes': [
      {'number': 482, 'title': 'WIP', 'isDraft': true, 'state': 'OPEN', 'url': 'u', 'reviewDecision': 'CHANGES_REQUESTED',
       'repository': {'name': 'r', 'owner': {'login': 'o'}},
       'commits': {'nodes': [{'commit': {'statusCheckRollup': {'state': 'FAILURE'}}}]}},
    ]},
    'projectItems': {'nodes': [{'fieldValues': {'nodes': [
      {'__typename': 'ProjectV2ItemFieldSingleSelectValue', 'name': 'In Progress', 'field': {'name': 'Status'}},
      {'__typename': 'ProjectV2ItemFieldSingleSelectValue', 'name': 'P1', 'field': {'name': 'Priority'}},
      {'__typename': 'ProjectV2ItemFieldNumberValue', 'number': 5, 'field': {'name': 'Complexity'}},
      {'__typename': 'ProjectV2ItemFieldIterationValue', 'title': 'Sprint 24', 'field': {'name': 'Sprint'}},
    ]}}]},
    'timelineItems': {'nodes': [
      {'__typename': 'IssueComment', 'createdAt': '2026-06-11T00:00:00Z', 'author': {'login': 'snguyen-tv'}, 'body': 'On it'},
      {'__typename': 'ClosedEvent', 'createdAt': '2026-06-12T00:00:00Z', 'actor': {'login': 'apatel-tv'}},
    ]},
  },
};

void main() {
  test('parses the issue node', () {
    final d = issueDetailFromNode('o', 'r', repoNode());
    expect(d.number, 155);
    expect(d.state, IssueState.open);
    expect(d.viewerCanUpdate, isTrue);
    expect(d.repoDefaultBranchOid, 'base-oid');
    expect(d.labels.single.name, 'bug');
    expect(d.milestone, 'v3');
    expect(d.status, IssueStatus.inProgress);
    expect(d.priority, IssuePriority.p1);
    expect(d.points, 5);
    expect(d.sprint, 'Sprint 24');
    expect(d.parent?.number, 99);
    expect(d.subDone, 1);
    expect(d.subIssues.first.done, isTrue);
    final pr = d.linkedPrs.single;
    expect(pr.ciState, PrCiState.failing);
    expect(pr.reviewState, PrReviewState.changesRequested);
    expect(pr.mergeState, PrLinkMergeState.draft);
    expect(d.timeline.first.kind, IssueEventKind.opened); // synthesized from createdAt
  });

  test('mock repo returns the sample and accepts mutations', () async {
    const repo = MockIssueDetailRepository();
    final res = await repo.fetchDetail('o', 'r', 1);
    expect(res.dataOrNull!.hasSubIssues, isTrue);
    expect((await repo.addComment('id', 'hi')).dataOrNull, isTrue);
    expect((await repo.closeIssue('id')).dataOrNull, isTrue);
    expect((await repo.createBranch('id', 'oid', '155-rotate')).dataOrNull, '155-rotate');
  });
}
```

> Before writing, confirm the `Result` accessor (`dataOrNull` vs `.when`) against `turbo_core`'s `core.dart` — match what `pr_detail_repository.dart` / `projects_board` tests use. If `dataOrNull` is absent, switch to `switch (res) { ResultSuccess(:final data) => data, ResultFailure(:final message) => fail(message) }`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/issue_detail/data/repositories/issue_detail_repository_test.dart`
Expected: FAIL — repository missing.

- [ ] **Step 3: Write the repository + mapper**

```dart
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
    for (final raw in ((item['fieldValues']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>()) {
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
        assignee: (s['assignees']?['nodes'] as List<dynamic>?)?.whereType<Map<String, dynamic>>().firstOrNull?['login']
            as String?,
      );
    }).toList();

List<LinkedPr> _linkedPrsFrom(Map<String, dynamic> issue) =>
    ((issue['closedByPullRequestsReferences']?['nodes'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((pr) {
          final rollup = (pr['commits']?['nodes'] as List<dynamic>?)?.whereType<Map<String, dynamic>>().firstOrNull?['commit']
              ?['statusCheckRollup']?['state'] as String?;
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
    events.add(IssueTimelineEvent(
      author: (issue['author']?['login'] as String?) ?? 'unknown',
      createdAt: opened,
      kind: IssueEventKind.opened,
    ));
  }
  for (final n in ((issue['timelineItems']?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>()) {
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
  labels: const [IssueLabel(name: 'bug', colorHex: 'e94a5f'), IssueLabel(name: 'security', colorHex: 'ffb000')],
  participants: const ['apatel-tv', 'snguyen-tv', 'tromero-tv'],
  status: IssueStatus.inProgress,
  priority: IssuePriority.p1,
  sprint: 'Sprint 24',
  points: 5,
  milestone: 'v3.0',
  parent: const IssueRef(repo: 'turbovets/web-portal', number: 99, title: 'RSC migration epic', status: IssueStatus.inProgress),
  subIssues: const [
    SubIssue(number: 156, title: 'Bind key to request context', status: IssueStatus.done, done: true, assignee: 'snguyen-tv'),
    SubIssue(number: 157, title: 'KMS issue per tenant', status: IssueStatus.inProgress, done: false, assignee: 'apatel-tv'),
    SubIssue(number: 158, title: 'Remove env.AUTH_KEY singleton', status: IssueStatus.notStarted, done: false),
  ],
  linkedPrs: const [
    LinkedPr(owner: 'turbovets', repo: 'web-portal', number: 482, title: 'Add per-request key rotation', isDraft: false,
        ciState: PrCiState.passing, reviewState: PrReviewState.approved, mergeState: PrLinkMergeState.open),
    LinkedPr(owner: 'turbovets', repo: 'web-portal', number: 155, title: 'WIP: server auth context', isDraft: true,
        ciState: PrCiState.failing, reviewState: PrReviewState.changesRequested, mergeState: PrLinkMergeState.draft),
  ],
  timeline: [
    IssueTimelineEvent(author: 'apatel-tv', createdAt: DateTime.utc(2026, 6, 10, 14, 30), kind: IssueEventKind.opened),
    IssueTimelineEvent(author: 'snguyen-tv', createdAt: DateTime.utc(2026, 6, 11, 9), kind: IssueEventKind.comment,
        bodyMarkdown: 'Started on the request-context binding — PR up shortly.'),
    IssueTimelineEvent(author: 'tromero-tv', createdAt: DateTime.utc(2026, 6, 12, 16), kind: IssueEventKind.labeled, detail: 'security'),
  ],
  viewerCanUpdate: true,
  repoDefaultBranchOid: 'deadbeefcafe',
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/issue_detail/data/repositories/issue_detail_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/issue_detail/data/repositories test/features/issue_detail/data/repositories
git commit -m "feat(issue-detail): repository, node mapper, mock sample"
```

---

### Task 4: Providers (repository, detail future, composer)

**Files:**
- Create: `lib/features/issue_detail/presentation/providers/issue_detail_provider.dart`
- Create: `lib/features/issue_detail/presentation/providers/issue_composer_provider.dart`
- Test: `test/features/issue_detail/presentation/providers/issue_detail_provider_test.dart`

**Interfaces:**
- Consumes: `githubApiClientProvider` (`repo_setup/presentation/providers/auth_provider.dart`), `IssueDetailRepository`/`GithubIssueDetailRepository`, `IssueDetail`.
- Produces: `issueDetailRepositoryProvider` (keepAlive), `issueDetailProvider(owner,repo,number)` (autodispose Future), `IssueComposer` (`issueComposerProvider`) with `comment`, `close`, `reopen`, `createBranch`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/issue_detail/presentation/providers/issue_detail_provider_test.dart
//
// Test summary:
// - issueDetailProvider yields the repo's issue on success.
// - issueDetailProvider surfaces repo failure as an AsyncError.
// - IssueComposer.comment: idle(null) -> loading -> data on success; invalidates the detail.
// - IssueComposer.close/reopen delegate to the repo and report success.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_core/core.dart';
import 'package:turbo_board/features/issue_detail/data/models/issue_detail.dart';
import 'package:turbo_board/features/issue_detail/data/repositories/issue_detail_repository.dart';
import 'package:turbo_board/features/issue_detail/presentation/providers/issue_composer_provider.dart';
import 'package:turbo_board/features/issue_detail/presentation/providers/issue_detail_provider.dart';

class _FailRepo implements IssueDetailRepository {
  @override
  Future<Result<IssueDetail>> fetchDetail(String o, String n, int num) async => Result.failure('boom', StackTrace.current);
  @override
  Future<Result<bool>> addComment(String s, String b) async => Result.success(true);
  @override
  Future<Result<bool>> closeIssue(String id) async => Result.success(true);
  @override
  Future<Result<bool>> reopenIssue(String id) async => Result.success(true);
  @override
  Future<Result<String>> createBranch(String id, String oid, String name) async => Result.success(name);
}

void main() {
  test('detail provider yields the repo issue', () async {
    final c = ProviderContainer(overrides: [
      issueDetailRepositoryProvider.overrideWithValue(const MockIssueDetailRepository()),
    ]);
    addTearDown(c.dispose);
    final d = await c.read(issueDetailProvider(owner: 'o', repo: 'r', number: 1).future);
    expect(d.number, 155);
  });

  test('detail provider surfaces failure as error', () async {
    final c = ProviderContainer(overrides: [issueDetailRepositoryProvider.overrideWithValue(_FailRepo())]);
    addTearDown(c.dispose);
    await expectLater(
      c.read(issueDetailProvider(owner: 'o', repo: 'r', number: 1).future),
      throwsA(isA<Exception>()),
    );
  });

  test('composer comment then close', () async {
    final c = ProviderContainer(overrides: [
      issueDetailRepositoryProvider.overrideWithValue(const MockIssueDetailRepository()),
    ]);
    addTearDown(c.dispose);
    final args = (owner: 'o', name: 'r', number: 1);
    expect(c.read(issueComposerProvider(owner: 'o', name: 'r', number: 1)), isNull);
    final ok = await c.read(issueComposerProvider(owner: 'o', name: 'r', number: 1).notifier).comment('id', 'hi');
    expect(ok, isTrue);
    expect(c.read(issueComposerProvider(owner: 'o', name: 'r', number: 1)), isA<AsyncData<void>>());
    expect(await c.read(issueComposerProvider(owner: 'o', name: 'r', number: 1).notifier).close('id'), isTrue);
    expect(args.number, 1); // keeps the analyzer happy about the record
  });
}
```

- [ ] **Step 2: Write the providers, then generate**

```dart
// lib/features/issue_detail/presentation/providers/issue_detail_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../data/models/issue_detail.dart';
import '../../data/repositories/issue_detail_repository.dart';

part 'issue_detail_provider.g.dart';

@Riverpod(keepAlive: true)
IssueDetailRepository issueDetailRepository(Ref ref) =>
    GithubIssueDetailRepository(ref.watch(githubApiClientProvider));

@riverpod
Future<IssueDetail> issueDetail(Ref ref, {required String owner, required String repo, required int number}) async {
  final result = await ref.watch(issueDetailRepositoryProvider).fetchDetail(owner, repo, number);
  return switch (result) {
    ResultSuccess(:final data) => data,
    ResultFailure(:final message) => throw Exception(message),
  };
}
```

```dart
// lib/features/issue_detail/presentation/providers/issue_composer_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import 'issue_detail_provider.dart';

part 'issue_composer_provider.g.dart';

/// Drives the issue comment composer + close/reopen + create-branch. State is
/// `null` when idle, [AsyncLoading] in flight, [AsyncData] on success,
/// [AsyncError] on failure. On success the matching [issueDetailProvider] is
/// invalidated so the timeline / state refreshes.
@riverpod
class IssueComposer extends _$IssueComposer {
  @override
  AsyncValue<void>? build({required String owner, required String name, required int number}) => null;

  Future<bool> _run(Future<Result<Object>> Function() op) async {
    state = const AsyncLoading();
    final res = await op();
    switch (res) {
      case ResultSuccess():
        state = const AsyncData(null);
        ref.invalidate(issueDetailProvider(owner: owner, repo: name, number: number));
        return true;
      case ResultFailure(:final message):
        state = AsyncError(message, StackTrace.current);
        return false;
    }
  }

  Future<bool> comment(String issueId, String body) =>
      _run(() => ref.read(issueDetailRepositoryProvider).addComment(issueId, body));

  Future<bool> close(String issueId) => _run(() => ref.read(issueDetailRepositoryProvider).closeIssue(issueId));

  Future<bool> reopen(String issueId) => _run(() => ref.read(issueDetailRepositoryProvider).reopenIssue(issueId));

  Future<bool> createBranch(String issueId, String oid, String name) =>
      _run(() => ref.read(issueDetailRepositoryProvider).createBranch(issueId, oid, name));
}
```

Run: `dart run build_runner build -d`
Expected: generates `issue_detail_provider.g.dart` + `issue_composer_provider.g.dart`.

> Note `issueDetailProvider`'s third positional arg name is `repo` (not `name`) — the composer maps its own `name` param to it on invalidate. Keep this consistent everywhere the provider is read (screen, entry points).

- [ ] **Step 3: Run tests to verify they pass**

Run: `flutter test test/features/issue_detail/presentation/providers/issue_detail_provider_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/features/issue_detail/presentation/providers test/features/issue_detail/presentation/providers
git commit -m "feat(issue-detail): detail + composer providers"
```

---

### Task 5: AI — issue summary + suggest-next-action

**Files:**
- Modify: `lib/features/ai/presentation/helpers/ai_prompts.dart` (add two builders)
- Modify: `lib/features/ai/data/repositories/ai_repository.dart` (interface + impl)
- Modify: `lib/features/ai/presentation/providers/ai_provider.dart` (two controllers)
- Test: `test/features/issue_detail/data/ai_issue_test.dart`

**Interfaces:**
- Consumes: `IssueDetail`, `AnthropicApiClient.complete`, `parseBullets` (existing in `ai_prompts.dart`).
- Produces: `buildIssueSummaryPrompt(IssueDetail)`, `buildNextActionPrompt(IssueDetail)`; `AiRepository.summarizeIssue` / `.suggestNextAction`; `IssueSummaryController` / `IssueNextActionController`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/issue_detail/data/ai_issue_test.dart
//
// Test summary:
// - buildIssueSummaryPrompt embeds title, body, status/priority and asks for bullets.
// - buildNextActionPrompt embeds open sub-issue + linked-PR signals and asks for one action.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/issue_detail/data/repositories/issue_detail_repository.dart';

void main() {
  test('issue summary prompt embeds the issue', () {
    final p = buildIssueSummaryPrompt(sampleIssueDetail);
    expect(p, contains('Rotate API keys'));
    expect(p, contains('bullet'));
  });

  test('next-action prompt asks for one action', () {
    final p = buildNextActionPrompt(sampleIssueDetail);
    expect(p, contains('#482')); // a linked PR signal
    expect(p.toLowerCase(), contains('next'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/issue_detail/data/ai_issue_test.dart`
Expected: FAIL — builders missing.

- [ ] **Step 3: Add prompts**

Append to `lib/features/ai/presentation/helpers/ai_prompts.dart` (add `import '../../../issue_detail/data/models/issue_detail.dart';` to the imports):

```dart
/// 3-bullet TL;DR of an issue, grounded in title + body + key project fields.
String buildIssueSummaryPrompt(IssueDetail i) {
  final fields = [
    if (i.status != null) 'Status: ${i.status!.name}',
    if (i.priority != null) 'Priority: ${i.priority!.name.toUpperCase()}',
    if (i.points != null) 'Estimate: ${i.points} pts',
    if (i.hasSubIssues) 'Sub-issues: ${i.subDone}/${i.subTotal} done',
    if (i.linkedPrs.isNotEmpty) 'Linked PRs: ${i.linkedPrs.length}',
  ].join(' · ');
  return '''
Summarize this GitHub issue as exactly 3 short bullet points a busy engineer can skim. Each bullet on its own line starting with "- ". No preamble.

Title: ${i.title}
$fields

Body:
${i.bodyMarkdown}
''';
}

/// One terse recommended next action, grounded in state + sub-issues + linked PRs.
String buildNextActionPrompt(IssueDetail i) {
  final signals = <String>[
    'State: ${i.state.name}',
    if (i.hasSubIssues) '${i.subTotal - i.subDone} sub-issues still open',
    for (final pr in i.linkedPrs)
      'PR #${pr.number} (${pr.title}): CI ${pr.ciState.name}, review ${pr.reviewState.name}, ${pr.mergeState.name}',
  ].join('\n');
  return '''
Given this issue's state, recommend the single most useful NEXT action for the assignee, in one short sentence (max ~15 words). No preamble, no bullet — just the sentence.

Issue: ${i.title}
$signals
''';
}
```

- [ ] **Step 4: Add the repo methods (interface + impl)**

In `ai_repository.dart`, add `import '../../issue_detail/data/models/issue_detail.dart';`, then to the `AiRepository` interface:

```dart
  /// 3-bullet TL;DR of an issue (title + body + fields).
  Future<Result<List<String>>> summarizeIssue(IssueDetail issue);

  /// One short recommended next action for an issue.
  Future<Result<String>> suggestNextAction(IssueDetail issue);
```

And to `AnthropicAiRepository`:

```dart
  @override
  Future<Result<List<String>>> summarizeIssue(IssueDetail issue) async {
    try {
      final text = await _anthropic.complete(prompt: buildIssueSummaryPrompt(issue), maxTokens: 350);
      final bullets = parseBullets(text);
      if (bullets.isEmpty) return Result.failure('The model returned an empty summary.', StackTrace.current);
      return Result.success(bullets);
    } catch (e, stackTrace) {
      log('Failed to summarize issue', error: e, stackTrace: stackTrace);
      return Result.failure('Could not generate a summary.', stackTrace);
    }
  }

  @override
  Future<Result<String>> suggestNextAction(IssueDetail issue) async {
    try {
      final text = (await _anthropic.complete(prompt: buildNextActionPrompt(issue), maxTokens: 120)).trim();
      if (text.isEmpty) return Result.failure('The model returned no suggestion.', StackTrace.current);
      return Result.success(text);
    } catch (e, stackTrace) {
      log('Failed to suggest next action', error: e, stackTrace: stackTrace);
      return Result.failure('Could not suggest a next action.', stackTrace);
    }
  }
```

- [ ] **Step 5: Add the controllers**

Append to `lib/features/ai/presentation/providers/ai_provider.dart` (add `import '../../../issue_detail/data/models/issue_detail.dart';`):

```dart
/// On-demand issue TL;DR, keyed by issue slug. `null` = not requested yet.
@riverpod
class IssueSummaryController extends _$IssueSummaryController {
  @override
  AsyncValue<List<String>>? build(String slug) => null;

  Future<void> generate(IssueDetail issue) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).summarizeIssue(issue);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }
}

/// On-demand "suggest next action", keyed by issue slug. `null` = not requested.
@riverpod
class IssueNextActionController extends _$IssueNextActionController {
  @override
  AsyncValue<String>? build(String slug) => null;

  Future<void> generate(IssueDetail issue) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).suggestNextAction(issue);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}
```

- [ ] **Step 6: Regenerate mocks + providers**

Run: `dart run build_runner build -d`
Expected: `ai_provider.g.dart` gains the two controllers; any `MockAiRepository` (mockito) used by AI tests regenerates with the two new methods stubbed. Existing AI tests still compile.

- [ ] **Step 7: Run tests**

Run: `flutter test test/features/issue_detail/data/ai_issue_test.dart test/features/ai`
Expected: PASS (new file + existing AI tests unaffected).

- [ ] **Step 8: Commit**

```bash
git add lib/features/ai test/features/issue_detail/data/ai_issue_test.dart
git commit -m "feat(issue-detail): AI issue summary + suggest-next-action"
```

---

### Task 6: AI sidebar widgets (summary card + next-action card)

**Files:**
- Create: `lib/features/ai/presentation/view/widgets/issue_summary_card.dart`
- Create: `lib/features/ai/presentation/view/widgets/issue_next_action_card.dart`

**Interfaces:** Consume `IssueDetail`, `aiKeyReadyProvider`, `issueSummaryControllerProvider`, `issueNextActionControllerProvider`, the shared `AiPrimaryButton`/`AiGhostButton` (`ai_buttons.dart`). Mirror `pr_summary_card.dart` structure (`null → CTA`, `AsyncLoading → spinner`, `AsyncError → message + TRY AGAIN`, `AsyncData → content + REGENERATE`).

- [ ] **Step 1: Write `issue_summary_card.dart`**

```dart
// lib/features/ai/presentation/view/widgets/issue_summary_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../issue_detail/data/models/issue_detail.dart';
import '../../providers/ai_provider.dart';
import 'ai_buttons.dart';

/// AI Issue TL;DR: 3 bullets generated on demand. Gradient top rule per design.
class IssueSummaryCard extends ConsumerWidget {
  const IssueSummaryCard({super.key, required this.issue});

  final IssueDetail issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(aiKeyReadyProvider);
    final summary = ref.watch(issueSummaryControllerProvider(issue.slug));
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0A3161), Color(0xFF13ACFF), Color(0xFF0A3161)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TbBadge('AI', TbSignal.info, small: true),
                    const SizedBox(width: 8),
                    Text('TL;DR', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4)),
                  ],
                ),
                const SizedBox(height: 12),
                if (!ready)
                  _needsKey(context)
                else
                  switch (summary) {
                    null => AiPrimaryButton(
                      label: 'SUMMARIZE WITH AI',
                      onPressed: () => ref.read(issueSummaryControllerProvider(issue.slug).notifier).generate(issue),
                    ),
                    AsyncLoading() => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    AsyncError(:final error) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$error', style: TbText.body(size: 13, color: TbSignal.bad.border)),
                        const SizedBox(height: 8),
                        AiGhostButton(
                          label: 'TRY AGAIN',
                          onPressed: () => ref.read(issueSummaryControllerProvider(issue.slug).notifier).generate(issue),
                        ),
                      ],
                    ),
                    AsyncData(:final value) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final bullet in value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, right: 8),
                                  child: TbSignalDot(color: TbColors.cyan, size: 6),
                                ),
                                Expanded(child: Text(bullet, style: TbText.body(size: 13, height: 1.4))),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        AiGhostButton(
                          label: 'REGENERATE',
                          onPressed: () => ref.read(issueSummaryControllerProvider(issue.slug).notifier).generate(issue),
                        ),
                      ],
                    ),
                  },
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _needsKey(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Add your Anthropic API key to enable AI summaries.', style: TbText.body(size: 13, color: TbColors.muted)),
      const SizedBox(height: 10),
      AiGhostButton(label: 'OPEN SETTINGS', onPressed: () => context.go('/settings')),
    ],
  );
}
```

- [ ] **Step 2: Write `issue_next_action_card.dart`**

A compact card driven by `issueNextActionControllerProvider(issue.slug)`: a `✦ SUGGEST NEXT ACTION` `AiGhostButton` when `null`, a spinner on `AsyncLoading`, the error + retry on `AsyncError`, and the suggestion text + a `CLEAR` ghost button on `AsyncData`. Same container styling as `IssueSummaryCard` minus the gradient rule. Gate on `aiKeyReadyProvider` exactly like the summary card (reuse the same `_needsKey` pattern). Use `TbText.body(size: 13)` for the suggestion.

```dart
// lib/features/ai/presentation/view/widgets/issue_next_action_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../issue_detail/data/models/issue_detail.dart';
import '../../providers/ai_provider.dart';
import 'ai_buttons.dart';

class IssueNextActionCard extends ConsumerWidget {
  const IssueNextActionCard({super.key, required this.issue});

  final IssueDetail issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(aiKeyReadyProvider);
    final next = ref.watch(issueNextActionControllerProvider(issue.slug));
    final notifier = ref.read(issueNextActionControllerProvider(issue.slug).notifier);
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT ACTION', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4)),
          const SizedBox(height: 10),
          if (!ready)
            AiGhostButton(label: 'OPEN SETTINGS', onPressed: () => context.go('/settings'))
          else
            switch (next) {
              null => AiGhostButton(label: '✦ SUGGEST NEXT ACTION', onPressed: () => notifier.generate(issue)),
              AsyncLoading() => const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              AsyncError(:final error) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$error', style: TbText.body(size: 13, color: TbSignal.bad.border)),
                  const SizedBox(height: 8),
                  AiGhostButton(label: 'TRY AGAIN', onPressed: () => notifier.generate(issue)),
                ],
              ),
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TbText.body(size: 13, height: 1.4)),
                  const SizedBox(height: 8),
                  AiGhostButton(label: 'CLEAR', onPressed: notifier.clear),
                ],
              ),
            },
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify analysis (no widget test yet — exercised in Task 8 screen test)**

Run: `dart analyze lib/features/ai/presentation/view/widgets/issue_summary_card.dart lib/features/ai/presentation/view/widgets/issue_next_action_card.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/ai/presentation/view/widgets/issue_summary_card.dart lib/features/ai/presentation/view/widgets/issue_next_action_card.dart
git commit -m "feat(issue-detail): AI summary + next-action sidebar cards"
```

---

### Task 7: Content + sidebar widgets

Build the issue body widgets. Each is a focused `StatelessWidget`/`HookConsumerWidget`. Match `Issue Detail.dc.html` tokens (card radius 8, badge radius 2, surface `TbColors.surface`, header bar `TbColors.surface2`, borders `TbColors.border`). Reuse `MarkdownBody(markdown)` (positional arg), `TbBadge(label, signal, small: true)`, `TbSignalDot(color:, size:)`, `TbAvatarTile(login:, size:)`, and `CockpitPalette.statusLabel(status)` / `CockpitPalette.statusDot(status)` from `lib/features/lead_cockpit/presentation/helpers/cockpit_palette.dart`.

**Files (create):**
- `lib/features/issue_detail/presentation/view/widgets/issue_description_card.dart`
- `lib/features/issue_detail/presentation/view/widgets/issue_sub_issues_card.dart`
- `lib/features/issue_detail/presentation/view/widgets/issue_linked_prs_card.dart`
- `lib/features/issue_detail/presentation/view/widgets/issue_timeline.dart`
- `lib/features/issue_detail/presentation/view/widgets/issue_comment_composer.dart`
- `lib/features/issue_detail/presentation/view/widgets/issue_sidebar_fields.dart`
- `lib/features/issue_detail/presentation/view/widgets/issue_development_card.dart`

**Test:** `test/features/issue_detail/presentation/widgets_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/issue_detail/presentation/widgets_test.dart
//
// Test summary:
// - IssueSubIssuesCard shows "{done}/{total} done" and one row per sub-issue.
// - IssueLinkedPrsCard renders a row per linked PR with its number.
// - IssueCommentComposer shows Comment + Close when viewerCanUpdate, and hides them when not.
// - IssueDevelopmentCard shows the Create branch CTA.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/issue_detail/data/repositories/issue_detail_repository.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/widgets/issue_comment_composer.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/widgets/issue_development_card.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/widgets/issue_linked_prs_card.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/widgets/issue_sub_issues_card.dart';

Widget _wrap(Widget child) =>
    ProviderScope(child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));

void main() {
  final issue = sampleIssueDetail;

  testWidgets('sub-issues card shows progress and rows', (tester) async {
    await tester.pumpWidget(_wrap(IssueSubIssuesCard(issue: issue, onTapSub: (_) {})));
    expect(find.textContaining('${issue.subDone}/${issue.subTotal}'), findsOneWidget);
    expect(find.textContaining('Bind key to request context'), findsOneWidget);
  });

  testWidgets('linked PRs card lists PRs', (tester) async {
    await tester.pumpWidget(_wrap(IssueLinkedPrsCard(prs: issue.linkedPrs, onTapPr: (_) {})));
    expect(find.textContaining('482'), findsWidgets);
  });

  testWidgets('composer hides actions without viewerCanUpdate', (tester) async {
    await tester.pumpWidget(_wrap(IssueCommentComposer(issue: issue.copyWith(viewerCanUpdate: false))));
    expect(find.text('Comment'), findsNothing);
  });

  testWidgets('development card shows create-branch CTA', (tester) async {
    await tester.pumpWidget(_wrap(IssueDevelopmentCard(issue: issue)));
    expect(find.textContaining('branch', findRichText: true), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/issue_detail/presentation/widgets_test.dart`
Expected: FAIL — widgets missing.

- [ ] **Step 3: Write `issue_description_card.dart`**

```dart
// lib/features/issue_detail/presentation/view/widgets/issue_description_card.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../pr_detail/presentation/view/widgets/markdown_body.dart';
import '../../../data/models/issue_detail.dart';

/// The issue body as a card: author header over the markdown body. MarkdownBody
/// already renders task-list checkboxes, fenced code, and tables.
class IssueDescriptionCard extends StatelessWidget {
  const IssueDescriptionCard({super.key, required this.issue});

  final IssueDetail issue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                Text(issue.author, style: TbText.body(size: 12, weight: FontWeight.w700)),
                const SizedBox(width: 7),
                Text('opened this issue', style: TbText.body(size: 12, color: TbColors.dim)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: MarkdownBody(issue.bodyMarkdown),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Write `issue_sub_issues_card.dart`**

```dart
// lib/features/issue_detail/presentation/view/widgets/issue_sub_issues_card.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../lead_cockpit/presentation/helpers/cockpit_palette.dart';
import '../../../data/models/issue_detail.dart';

/// Sub-issue task list with a done/total progress bar. Rows are tappable.
class IssueSubIssuesCard extends StatelessWidget {
  const IssueSubIssuesCard({super.key, required this.issue, required this.onTapSub});

  final IssueDetail issue;
  final void Function(SubIssue) onTapSub;

  @override
  Widget build(BuildContext context) {
    final pct = issue.subTotal == 0 ? 0.0 : issue.subDone / issue.subTotal;
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                Text('SUB-ISSUES', style: TbText.label(size: 11, tracking: 1.0)),
                const SizedBox(width: 10),
                Text('${issue.subDone}/${issue.subTotal} done', style: TbText.label(size: 10, color: TbColors.muted)),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: TbColors.canvas,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF54AE39)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final s in issue.subIssues)
            InkWell(
              onTap: () => onTapSub(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TbColors.border))),
                child: Row(
                  children: [
                    Icon(s.done ? Icons.check_box : Icons.check_box_outline_blank, size: 15,
                        color: s.done ? const Color(0xFF54AE39) : TbColors.muted),
                    const SizedBox(width: 10),
                    Text('#${s.number}', style: TbText.label(size: 10, color: TbColors.dim)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TbText.body(
                          size: 13,
                          color: s.done ? TbColors.muted : TbColors.text,
                        ).copyWith(decoration: s.done ? TextDecoration.lineThrough : null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TbBadge(CockpitPalette.statusLabel(s.status), TbSignal.gray, small: true),
                    if (s.assignee != null) ...[const SizedBox(width: 8), TbAvatarTile(login: s.assignee!, size: 19)],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Write `issue_linked_prs_card.dart`**

```dart
// lib/features/issue_detail/presentation/view/widgets/issue_linked_prs_card.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../pr_inbox/data/models/pr_data.dart';
import '../../../data/models/issue_detail.dart';

/// Linked pull requests with CI / review / merge signal dots. Rows tappable.
class IssueLinkedPrsCard extends StatelessWidget {
  const IssueLinkedPrsCard({super.key, required this.prs, required this.onTapPr});

  final List<LinkedPr> prs;
  final void Function(LinkedPr) onTapPr;

  static const _green = Color(0xFF54AE39);
  static const _red = Color(0xFFE94A5F);
  static const _amber = Color(0xFFFFB000);
  static const _gray = Color(0xFF45454C);

  Color _ci(PrCiState s) => switch (s) {
    PrCiState.passing => _green,
    PrCiState.failing => _red,
    PrCiState.pending => _amber,
  };
  Color _rev(PrReviewState s) => switch (s) {
    PrReviewState.approved => _green,
    PrReviewState.changesRequested => _red,
    PrReviewState.needsReview => const Color(0xFF13ACFF),
    PrReviewState.waitingOnAuthor => _gray,
  };
  (Color, String) _merge(PrLinkMergeState s) => switch (s) {
    PrLinkMergeState.merged => (const Color(0xFF8957E5), 'MERGED'),
    PrLinkMergeState.closed => (_red, 'CLOSED'),
    PrLinkMergeState.draft => (_gray, 'DRAFT'),
    PrLinkMergeState.open => (_green, 'OPEN'),
  };

  @override
  Widget build(BuildContext context) {
    if (prs.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Text('LINKED PULL REQUESTS', style: TbText.label(size: 11, tracking: 1.0)),
          ),
          for (final pr in prs)
            InkWell(
              onTap: () => onTapPr(pr),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TbColors.border))),
                child: Row(
                  children: [
                    const Icon(Icons.merge_type, size: 14, color: Color(0xFF13ACFF)),
                    const SizedBox(width: 8),
                    Text('#${pr.number}', style: TbText.label(size: 10, color: TbColors.dim)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(pr.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TbText.body(size: 13))),
                    if (pr.isDraft) ...[const SizedBox(width: 6), TbBadge('DRAFT', TbSignal.gray, small: true)],
                    const SizedBox(width: 10),
                    TbSignalDot(color: _ci(pr.ciState), size: 8),
                    const SizedBox(width: 6),
                    TbSignalDot(color: _rev(pr.reviewState), size: 8),
                    const SizedBox(width: 6),
                    Builder(builder: (_) {
                      final (c, label) = _merge(pr.mergeState);
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        TbSignalDot(color: c, size: 8),
                        const SizedBox(width: 4),
                        Text(label, style: TbText.label(size: 9, color: TbColors.muted)),
                      ]);
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Write `issue_timeline.dart`**

Mirror `lib/features/pr_detail/presentation/view/widgets/pr_timeline.dart` (read it for the rail + event-row + comment-card styling). It takes `List<IssueTimelineEvent> events` and renders each: `comment` → a comment card (author header + `MarkdownBody(bodyMarkdown)`); everything else → a compact one-line event with an icon. Map kinds to text:

```dart
// lib/features/issue_detail/presentation/view/widgets/issue_timeline.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../pr_detail/presentation/view/widgets/markdown_body.dart';
import '../../../data/models/issue_detail.dart';

class IssueTimeline extends StatelessWidget {
  const IssueTimeline({super.key, required this.events});

  final List<IssueTimelineEvent> events;

  String _eventText(IssueTimelineEvent e) => switch (e.kind) {
    IssueEventKind.opened => '${e.author} opened this issue',
    IssueEventKind.closed => '${e.author} closed this issue',
    IssueEventKind.reopened => '${e.author} reopened this issue',
    IssueEventKind.labeled => '${e.author} added the ${e.detail ?? ''} label',
    IssueEventKind.assigned => '${e.author} assigned ${e.detail ?? ''}',
    IssueEventKind.unassigned => '${e.author} unassigned ${e.detail ?? ''}',
    IssueEventKind.crossReferenced => '${e.author} referenced #${e.detail ?? ''}',
    IssueEventKind.renamed => '${e.author} renamed this to "${e.detail ?? ''}"',
    IssueEventKind.comment => '',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: e.kind == IssueEventKind.comment
                ? _CommentCard(event: e)
                : Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: TbColors.muted),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_eventText(e), style: TbText.body(size: 12, color: TbColors.muted))),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.event});

  final IssueTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                Text(event.author, style: TbText.body(size: 12, weight: FontWeight.w700)),
                const SizedBox(width: 7),
                Text('commented', style: TbText.body(size: 12, color: TbColors.dim)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: MarkdownBody(event.bodyMarkdown),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Write `issue_comment_composer.dart`**

Mirror `lib/features/pr_detail/presentation/view/widgets/pr_comment_composer.dart` (read it for the textarea + button-row styling). `HookConsumerWidget`; gated on `issue.viewerCanUpdate` (render nothing / a muted note when false). Uses `issueComposerProvider(owner:, name:, number:)` derived from `issue.repo`.split('/').

```dart
// lib/features/issue_detail/presentation/view/widgets/issue_comment_composer.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../data/models/issue_detail.dart';
import '../../providers/issue_composer_provider.dart';

class IssueCommentComposer extends HookConsumerWidget {
  const IssueCommentComposer({super.key, required this.issue});

  final IssueDetail issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!issue.viewerCanUpdate) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('You don\'t have write access to comment on this issue.',
            style: TbText.body(size: 12, color: TbColors.muted)),
      );
    }
    final parts = issue.repo.split('/');
    final owner = parts.first;
    final name = parts.length > 1 ? parts[1] : '';
    final args = (owner: owner, name: name, number: issue.number);
    final controller = useTextEditingController();
    final state = ref.watch(issueComposerProvider(owner: owner, name: name, number: issue.number));
    final notifier = ref.read(issueComposerProvider(owner: owner, name: name, number: issue.number).notifier);
    final busy = state is AsyncLoading;
    final id = issue.id;

    Future<void> submitComment() async {
      if (id == null || controller.text.trim().isEmpty) return;
      final ok = await notifier.comment(id, controller.text.trim());
      if (ok) controller.clear();
    }

    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              style: TbText.body(size: 13, color: TbColors.text),
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Leave a comment…'),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: TbColors.border))),
            child: Row(
              children: [
                Text('Markdown supported', style: TbText.label(size: 9, color: TbColors.muted)),
                const Spacer(),
                TextButton(
                  onPressed: busy || id == null
                      ? null
                      : () => issue.isClosed ? notifier.reopen(id) : notifier.close(id),
                  child: Text(issue.isClosed ? 'Reopen issue' : 'Close issue'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: busy ? null : submitComment, child: const Text('Comment')),
              ],
            ),
          ),
        ],
      ),
    );
    // ignore: dead_code — `args` documents the provider key shape for readers.
  }
}
```

> Remove the trailing `args` note if the analyzer flags it; it is illustrative only. The provider key is `(owner, name, number)`.

- [ ] **Step 8: Write `issue_sidebar_fields.dart`**

A column of small cards rendering the project sidebar. Sections, each a bordered card with a `surface2` header (label via `TbText.label(size: 10, tracking: 1.0)`):
- **Assignees** — avatar (`TbAvatarTile`) + login rows; skip card if empty.
- **Labels** — wrap of chips colored from `IssueLabel.colorHex` (parse `int.parse('FF$hex', radix: 16)` → `Color`); skip if empty.
- **Project** — field rows `label · value`: Status (`TbBadge(CockpitPalette.statusLabel(status), TbSignal.gray, small:true)`), Priority (`TbBadge(priority.name.toUpperCase(), CockpitPalette.prioritySignal(priority), small:true)`), Sprint (text), Complexity (`${points} pts`), Milestone (text). Skip rows whose value is null.
- **Relationships** — parent epic row (`#${parent.number} ${parent.title}`), tappable → `onTapRef(parent)`; skip if null.
- **Participants** — overlapping avatar cluster + "N participants".

Signature: `IssueSidebarFields({required IssueDetail issue, required void Function(IssueRef) onTapRef})`. Build with the same container styling used above. (No code block required — this is straight composition of already-shown primitives; keep each section a private `Widget _build…()` returning `SizedBox.shrink()` when empty.)

- [ ] **Step 9: Write `issue_development_card.dart`**

```dart
// lib/features/issue_detail/presentation/view/widgets/issue_development_card.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/open_in_github_desktop_button.dart';
import '../../../../../shared/ui/widgets/open_on_github_button.dart';
import '../../../data/models/issue_detail.dart';
import '../../providers/issue_composer_provider.dart';

/// "Development" actions: create a branch from the issue, open it in GitHub
/// Desktop once created, and open the issue on github.com.
class IssueDevelopmentCard extends HookConsumerWidget {
  const IssueDevelopmentCard({super.key, required this.issue});

  final IssueDetail issue;

  String _branchName() {
    final slug = issue.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final short = slug.length > 40 ? slug.substring(0, 40) : slug;
    return '${issue.number}-$short';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = issue.repo.split('/');
    final owner = parts.first;
    final name = parts.length > 1 ? parts[1] : '';
    final notifier = ref.read(issueComposerProvider(owner: owner, name: name, number: issue.number).notifier);
    final createdBranch = useState<String?>(null);
    final oid = issue.repoDefaultBranchOid;
    final id = issue.id;

    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Text('DEVELOPMENT', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.0)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (createdBranch.value == null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.account_tree_outlined, size: 14),
                    label: Text('Create branch  ${_branchName()}', overflow: TextOverflow.ellipsis),
                    onPressed: (id == null || oid == null)
                        ? null
                        : () async {
                            final ok = await notifier.createBranch(id, oid, _branchName());
                            if (ok) createdBranch.value = _branchName();
                          },
                  )
                else ...[
                  Text('Branch: ${createdBranch.value}', style: TbText.body(size: 12)),
                  const SizedBox(height: 8),
                  OpenInGitHubDesktopButton(
                    repo: issue.repo,
                    headRefName: createdBranch.value!,
                    number: issue.number,
                    isCrossRepository: false,
                  ),
                ],
                const SizedBox(height: 8),
                if (issue.url != null) OpenOnGitHubButton.labeled(url: issue.url!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

> Confirm `OpenInGitHubDesktopButton`'s required params (`repo`, `headRefName`, `number`, `isCrossRepository`, optional `compact`) against `lib/shared/ui/widgets/open_in_github_desktop_button.dart` before wiring; pass `compact: context.isMobile` if available.

- [ ] **Step 10: Run the widget test to verify it passes**

Run: `flutter test test/features/issue_detail/presentation/widgets_test.dart`
Expected: PASS (4 tests). Adjust finders only if a label string differs from what you rendered.

- [ ] **Step 11: Commit**

```bash
git add lib/features/issue_detail/presentation/view/widgets test/features/issue_detail/presentation/widgets_test.dart
git commit -m "feat(issue-detail): content + sidebar widgets"
```

---

### Task 8: Issue Detail screen (drawer assembly)

**Files:**
- Create: `lib/features/issue_detail/presentation/view/issue_detail_screen.dart`
- Test: `test/features/issue_detail/presentation/issue_detail_screen_test.dart`

**Interfaces:**
- Consumes: `issueDetailProvider`, all Task 6/7 widgets, `IssueSummaryCard`/`IssueNextActionCard`, `TbBreakpoints`, `TbColors`, GoRouter `context.push`/`pop`.
- Produces: `class IssueDetailScreen extends ConsumerWidget { static const routeName = 'issueDetail'; const IssueDetailScreen({required this.owner, required this.repo, required this.number}); }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/issue_detail/presentation/issue_detail_screen_test.dart
//
// Test summary:
// - With the mock repo, the screen renders the issue title and the AI TL;DR header.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/issue_detail/data/repositories/issue_detail_repository.dart';
import 'package:turbo_board/features/issue_detail/presentation/providers/issue_detail_provider.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/issue_detail_screen.dart';

void main() {
  testWidgets('renders the issue title from the mock repo', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const IssueDetailScreen(owner: 'turbovets', repo: 'web-portal', number: 155)),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [issueDetailRepositoryProvider.overrideWithValue(const MockIssueDetailRepository())],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rotate API keys'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/issue_detail/presentation/issue_detail_screen_test.dart`
Expected: FAIL — screen missing.

- [ ] **Step 3: Write the screen**

Copy the drawer chrome from `pr_detail_screen.dart` (the `LayoutBuilder` → scrim + `SlideTransition` + `_DrawerPanel` with a 58px header reading `ISSUE #n` + refresh + close, the `_close` helper, and the `drawerW` formula). Then build `_DetailBody`:

- Header section: repo line (`TbSignalDot(color: TbRepoColor.forSlug(repo))` + `repo`) with `OpenOnGitHubButton.labeled(url:)` when `issue.url != null`; title + `#number`; a `Wrap` with the state badge (`TbBadge(issue.isClosed ? 'CLOSED' : 'OPEN', issue.isClosed ? TbSignal.gray : TbSignal.ok, small: true)`), author `TbAvatarTile` + "opened …", and "· {commentCount} comments".
- `main` column: `IssueDescriptionCard`, `IssueSubIssuesCard(issue:, onTapSub: (s) => context.push('/issue/$owner/$repo/${s.number}'))`, `IssueLinkedPrsCard(prs: issue.linkedPrs, onTapPr: (pr) => context.push('/pr/${pr.owner}/${pr.repo}/${pr.number}'))`, an "ACTIVITY" label, `IssueTimeline(events: issue.timeline)`, `IssueCommentComposer(issue: issue)`.
- `aside` column (322px): `IssueSummaryCard(issue:)`, `IssueNextActionCard(issue:)`, `IssueSidebarFields(issue:, onTapRef: (r) { final p = r.repo.split('/'); context.push('/issue/${p.first}/${p.length>1?p[1]:''}/${r.number}'); })`, `IssueDevelopmentCard(issue:)`.
- Layout: `LayoutBuilder` — `< 720` stacked with the **aside first** (AI TL;DR leads on phone, per design); `>= 720` `Row(main, 18px gap, SizedBox(width: 322, child: aside))`.

```dart
// lib/features/issue_detail/presentation/view/issue_detail_screen.dart  (skeleton — fill the body per the bullets above)
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../shared/ui/theme/tb_breakpoints.dart';
import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/open_on_github_button.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../../ai/presentation/view/widgets/issue_next_action_card.dart';
import '../../../ai/presentation/view/widgets/issue_summary_card.dart';
import '../../data/models/issue_detail.dart';
import '../providers/issue_detail_provider.dart';
import 'widgets/issue_comment_composer.dart';
import 'widgets/issue_description_card.dart';
import 'widgets/issue_development_card.dart';
import 'widgets/issue_linked_prs_card.dart';
import 'widgets/issue_sidebar_fields.dart';
import 'widgets/issue_sub_issues_card.dart';
import 'widgets/issue_timeline.dart';

class IssueDetailScreen extends ConsumerWidget {
  const IssueDetailScreen({super.key, required this.owner, required this.repo, required this.number});

  static const String routeName = 'issueDetail';

  final String owner;
  final String repo;
  final int number;

  void _close(BuildContext context) => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(issueDetailProvider(owner: owner, repo: repo, number: number));
    // ... copy the scrim + SlideTransition + _DrawerPanel chrome from pr_detail_screen.dart,
    //     swapping the header label to 'ISSUE  #$number' and the data widget to _DetailBody.
    //     detail.when(loading/error(+Retry via ref.invalidate(issueDetailProvider(...)))/data: (d)=>_DetailBody(d)).
    throw UnimplementedError('replace with the chrome described above');
  }
}
```

> Implement the chrome by transcribing `pr_detail_screen.dart` lines for the scrim/slide/`_DrawerPanel`/`_CloseButton`/`_HeaderIconButton`, then write `_DetailBody` per the bullet list. The `throw` is a placeholder for the engineer to replace — the surrounding imports and signature are correct.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/issue_detail/presentation/issue_detail_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/issue_detail/presentation/view/issue_detail_screen.dart test/features/issue_detail/presentation/issue_detail_screen_test.dart
git commit -m "feat(issue-detail): drawer screen assembly"
```

---

### Task 9: Routing

**Files:**
- Modify: `lib/shared/router/app_router.dart` (import + GoRoute), then `dart run build_runner build -d`
- Test: `test/shared/router/issue_route_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/router/issue_route_test.dart
//
// Test summary:
// - The router exposes a route named IssueDetailScreen.routeName under the shell.
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/issue_detail_screen.dart';
import 'package:turbo_board/shared/router/app_router.dart';

void main() {
  test('issue detail route is registered', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final router = c.read(appRouterProvider);
    final shell = router.configuration.routes.whereType<ShellRoute>().first;
    expect(shell.routes.whereType<GoRoute>().any((r) => r.name == IssueDetailScreen.routeName), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/router/issue_route_test.dart`
Expected: FAIL — route not registered.

- [ ] **Step 3: Add the route**

In `app_router.dart`, add the import:

```dart
import '../../features/issue_detail/presentation/view/issue_detail_screen.dart';
```

and add this `GoRoute` inside the ShellRoute `routes:` list, right after the `/pr/:owner/:repo/:number` route:

```dart
          GoRoute(
            path: '/issue/:owner/:repo/:number',
            name: IssueDetailScreen.routeName,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              opaque: false,
              barrierDismissible: false,
              transitionDuration: const Duration(milliseconds: 220),
              child: IssueDetailScreen(
                owner: state.pathParameters['owner']!,
                repo: state.pathParameters['repo']!,
                number: int.tryParse(state.pathParameters['number'] ?? '') ?? 0,
              ),
              transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
            ),
          ),
```

Run: `dart run build_runner build -d` (regenerates `app_router.g.dart` if needed).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/router/issue_route_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/router/app_router.dart test/shared/router/issue_route_test.dart
git commit -m "feat(issue-detail): register /issue/:owner/:repo/:number route"
```

---

### Task 10: Entry point — Lead Cockpit stuck-issue rows

**Files:**
- Modify: `lib/features/lead_cockpit/presentation/view/widgets/stuck_issue_row.dart`

**Context:** `StuckIssueRow` currently opens `issue.url` via `launchUrl` (line ~144). Re-point its tap to push the in-app drawer. It is a `StatelessWidget` with a `BuildContext` in `build`, so `context.push` is available.

- [ ] **Step 1: Inspect the row's issue fields**

Run: `grep -nE 'final issue|issue\.(repo|url|number|owner)|class StuckIssueRow' lib/features/lead_cockpit/presentation/view/widgets/stuck_issue_row.dart`
Note whether the row's `issue` exposes `repo` ("owner/name") + `number` directly. If it only has `url`, derive owner/repo/number from the GitHub URL (`/{owner}/{repo}/issues/{number}`).

- [ ] **Step 2: Replace the tap handler**

Add `import 'package:go_router/go_router.dart';` if absent. Change the `onTap` from `launchUrl(...)` to push the drawer. If the row exposes `issue.repo` + `issue.number`:

```dart
onTap: () {
  final parts = issue.repo.split('/');
  if (parts.length == 2) {
    context.push('/issue/${parts[0]}/${parts[1]}/${issue.number}');
  } else if (url != null) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
},
```

If only `url` is available, parse it:

```dart
onTap: () {
  final u = url == null ? null : Uri.tryParse(url);
  final seg = u?.pathSegments ?? const [];
  // /{owner}/{repo}/issues/{number}
  if (seg.length >= 4 && seg[2] == 'issues') {
    context.push('/issue/${seg[0]}/${seg[1]}/${seg[3]}');
  } else if (url != null) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
},
```

Keep `url_launcher` import as the fallback path still uses it.

- [ ] **Step 3: Verify analysis + cockpit tests**

Run: `dart analyze lib/features/lead_cockpit/presentation/view/widgets/stuck_issue_row.dart && flutter test test/features/lead_cockpit`
Expected: No analyzer issues; cockpit tests still pass (the change is tap-only).

- [ ] **Step 4: Commit**

```bash
git add lib/features/lead_cockpit/presentation/view/widgets/stuck_issue_row.dart
git commit -m "feat(issue-detail): open stuck cockpit issues in the in-app drawer"
```

---

### Task 11: Entry point — PR Detail ↔ Issue cross-link

**Files:**
- Modify: `lib/features/pr_detail/data/queries/pr_detail_query.dart` (add `closingIssuesReferences`)
- Modify: `lib/features/pr_detail/data/models/pr_detail.dart` (add `linkedIssues`)
- Modify: `lib/features/pr_detail/data/repositories/pr_detail_repository.dart` (parse it)
- Modify: `lib/features/pr_detail/presentation/view/pr_detail_screen.dart` (add a Linked-issues card to `aside`)
- Test: `test/features/pr_detail/linked_issues_test.dart`

**Interfaces:** Reuse `IssueRef` from `issue_detail/data/models/issue_detail.dart`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/pr_detail/linked_issues_test.dart
//
// Test summary:
// - prDetailFromNode parses closingIssuesReferences into PrDetail.linkedIssues.
// - the query selects closingIssuesReferences.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_detail/data/queries/pr_detail_query.dart';
import 'package:turbo_board/features/pr_detail/data/repositories/pr_detail_repository.dart';

void main() {
  test('query selects closing issue references', () {
    expect(prDetailQuery, contains('closingIssuesReferences'));
  });

  test('parses linked issues from the node', () {
    final repoNode = <String, dynamic>{'viewerPermission': 'READ'};
    final pr = <String, dynamic>{
      'number': 1, 'title': 't', 'state': 'OPEN', 'author': {'login': 'a'},
      'baseRefName': 'main', 'headRefName': 'f',
      'closingIssuesReferences': {'nodes': [
        {'number': 155, 'title': 'Rotate keys', 'state': 'OPEN', 'repository': {'nameWithOwner': 'o/r'}},
      ]},
    };
    final d = prDetailFromNode('o', 'r', repoNode, pr);
    expect(d.linkedIssues.single.number, 155);
    expect(d.linkedIssues.single.repo, 'o/r');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/pr_detail/linked_issues_test.dart`
Expected: FAIL — `closingIssuesReferences` not in query / `linkedIssues` not on `PrDetail`.

- [ ] **Step 3: Add the query selection**

In `pr_detail_query.dart`, inside `pullRequest(number: $number) { … }`, add after the `comments(...)` block:

```graphql
      closingIssuesReferences(first: 10) {
        nodes { number title state repository { nameWithOwner } }
      }
```

- [ ] **Step 4: Add the model field**

In `pr_detail.dart`, add the import `import '../../../issue_detail/data/models/issue_detail.dart' show IssueRef;` and a field to the `PrDetail` factory:

```dart
    @Default(<IssueRef>[]) List<IssueRef> linkedIssues,
```

Run: `dart run build_runner build -d` (regenerates `pr_detail.freezed.dart`).

- [ ] **Step 5: Parse it in the repository**

In `prDetailFromNode` (`pr_detail_repository.dart`), add to the returned `PrDetail(...)`:

```dart
    linkedIssues: ((pr['closingIssuesReferences']?['nodes'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((i) => IssueRef(
              repo: (i['repository']?['nameWithOwner'] as String?) ?? '',
              number: (i['number'] as num?)?.toInt() ?? 0,
              title: (i['title'] as String?) ?? '',
            ))
        .toList(),
```

Add `import '../../../issue_detail/data/models/issue_detail.dart' show IssueRef;` to the repository file.

- [ ] **Step 6: Run the parse test**

Run: `flutter test test/features/pr_detail/linked_issues_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Add the Linked-issues card to PR Detail**

In `pr_detail_screen.dart`, in `_DetailBody`'s `aside` column, after `PrReviewersCard(...)` add (only when non-empty):

```dart
if (detail.linkedIssues.isNotEmpty) ...[
  const SizedBox(height: 12),
  _LinkedIssuesCard(issues: detail.linkedIssues),
],
```

and define a small `_LinkedIssuesCard` (private, in the same file) that renders a bordered card titled "LINKED ISSUES" with one tappable row per issue (`#${i.number} ${i.title}`), each pushing the drawer:

```dart
class _LinkedIssuesCard extends StatelessWidget {
  const _LinkedIssuesCard({required this.issues});
  final List<IssueRef> issues;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Text('LINKED ISSUES', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.0)),
          ),
          for (final i in issues)
            InkWell(
              onTap: () {
                final p = i.repo.split('/');
                if (p.length == 2) context.push('/issue/${p[0]}/${p[1]}/${i.number}');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                child: Row(
                  children: [
                    Text('#${i.number}', style: TbText.label(size: 10, color: TbColors.dim)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TbText.body(size: 13, color: TbColors.cyan))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

Add `import '../../../issue_detail/data/models/issue_detail.dart' show IssueRef;` to `pr_detail_screen.dart` if not already pulled in transitively.

- [ ] **Step 8: Verify PR Detail still builds + tests pass**

Run: `dart analyze lib/features/pr_detail && flutter test test/features/pr_detail`
Expected: No analyzer issues; PR Detail tests pass.

- [ ] **Step 9: Commit**

```bash
git add lib/features/pr_detail test/features/pr_detail/linked_issues_test.dart
git commit -m "feat(issue-detail): PR Detail <-> Issue cross-link"
```

---

### Task 12: Deferred integration — Projects Board issue-card tap

> **Not buildable on this branch.** The `projects_board` feature lives on the `feat/projects-board` branch and is not present on `main`/`feat/issue-detail`. Do this step on the integration branch **after both features merge**.

**When both are merged:** in `ProjectsBoardScreen`'s card-tap handler, change the issue branch from "open GitHub URL" to:

```dart
context.push('/issue/${card.owner}/${card.repo}/${card.number}');
```

PR cards keep pushing `/pr/...`. Add/keep a board widget test asserting an issue-card tap navigates to the `/issue/...` route. Commit:

```bash
git commit -m "feat(issue-detail): open board issue cards in the in-app drawer"
```

- [ ] **Step 1 (tracking only):** leave this task unchecked until the integration branch exists. Note it in the PR description so it isn't forgotten.

---

### Task 13: Full verification

- [ ] **Step 1: Format**

Run: `dart format --line-length 120 --set-exit-if-changed .`
Expected: zero files changed. If any are listed, run `dart format --line-length 120 .` and re-check.

- [ ] **Step 2: Analyze**

Run: `dart analyze`
Expected: No issues found.

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all green.

- [ ] **Step 4: Manual smoke (one desktop + web)**

Run: `flutter run -d macos` then `flutter run -d chrome`. From the Lead Cockpit, tap a stuck issue → the drawer slides in over the board with the sample issue; the AI TL;DR + Suggest-next-action CTAs appear (or the "add key" prompt); the comment composer + Close/Reopen + Create-branch render; ✕ and scrim-tap close it. Open a PR with a linked issue → the Linked-issues card pushes the issue drawer.

- [ ] **Step 5: Commit any formatting fixups**

```bash
git add -A
git commit -m "chore(issue-detail): format + analyze pass"
```

---

## Self-Review Notes

- **Spec coverage:** models (T1), query+mutations (T2), repo+mapper+mock (T3), providers+composer (T4), AI TL;DR + next-action (T5–T6), all content/sidebar/development widgets (T7), drawer screen + phone-stacked-AI-first (T8), route (T9), three entry points (T10 cockpit, T11 PR cross-link, T12 board deferred), responsive formula + verification (T8/T13). ✓
- **Reuse correction vs spec:** `LinkedPr` reuses `PrCiState`/`PrReviewState`/`PrMergeState` from `pr_inbox/data/models/pr_data.dart` (on `main`), NOT the board's `board_data.dart` (absent on this branch). `PrLinkMergeState` is a new local enum (richer than `PrMergeState`). ✓
- **Type consistency:** `issueDetailProvider(owner:, repo:, number:)`, `issueComposerProvider(owner:, name:, number:)`, `IssueDetailRepository.{fetchDetail,addComment,closeIssue,reopenIssue,createBranch}`, `IssueSummaryController`/`IssueNextActionController` keyed by `slug`, `IssueDetail.{slug,subDone,subTotal,hasSubIssues,isClosed}` are used identically across tasks. ✓
- **Open verifications flagged inline:** `Result` accessor (`dataOrNull` vs `.when`) in T3/T4; `OpenInGitHubDesktopButton` params in T9; stuck-row issue fields in T10. These are "confirm against the file" notes, not placeholders.
- **Known placeholder:** T8 Step 3 ships a `throw UnimplementedError` skeleton with a transcribe-from-`pr_detail_screen.dart` instruction, because the drawer chrome is a verbatim copy of an existing file rather than novel code. The engineer replaces it; the screen test (T8 Step 1) fails until they do.
