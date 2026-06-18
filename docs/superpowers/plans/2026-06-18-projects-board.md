# Projects Board Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A read-only GitHub ProjectV2 kanban board grouped by Status, with mixed issue/PR cards and an on-demand AI per-column insight CTA.

**Architecture:** New `lib/features/projects_board/` feature mirroring the data/presentation split. Reuses the lead_cockpit ProjectV2 query (extended for PRs), `SelectedProjectNotifier`, `availableProjectsProvider`, `ProjectPickerList`, and the BYOK Anthropic client. A pure mapper turns raw project items into `ProjectBoardData`; an on-demand controller layers AI insights over it. Nothing touches `cockpit_mapper.dart` or `CockpitData`.

**Tech Stack:** Flutter, Riverpod (+riverpod_annotation/codegen), Freezed, GoRouter, flutter_hooks, mockito, turbo_core `Result`, turbo_ui Tether tokens.

## Global Constraints

- `dart format --line-length 120 --set-exit-if-changed .` must pass (CI rejects unformatted).
- `dart analyze` clean; `flutter test` green.
- Depend on `turbo_core` + `turbo_ui` only; no mobile-only plugins; no `dart:io` in shared paths.
- Freezed `sealed class` models with `fromJson`; `@freezed`. Never edit `*.freezed.dart`/`*.g.dart`/`*.mocks.dart` by hand — regenerate with `dart run build_runner build -d`.
- Riverpod: `@Riverpod(keepAlive: true)` for repos/global; lowercase `@riverpod` for autodispose. On-demand AI controllers default state `null` (= not requested), mirroring `PrSummaryController`.
- Errors caught only in the repo layer; surfaced above as `Result` (`turbo_core`).
- Tether tokens from `lib/shared/ui/theme/tb_tokens.dart` (`TbColors`, `TbSignal`, `TbAvatar`, `TbRepoColor`); text via `TbText`; breakpoints `TbBreakpoints.mobile`=640, `.tablet`=1100.
- Each test file starts with a test-summary comment listing its cases (CLAUDE.md).
- Conventional Commits; end commit bodies with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Verbatim layout numbers from `Projects Board.dc.html`: card radius 8 / badge radius 4; column width 236 (272 for In Progress); column gap 14; card padding 12; topbar height 58.

---

### Task 1: Board data models

**Files:**
- Create: `lib/features/projects_board/data/models/board_data.dart`
- Test: `test/features/projects_board/data/models/board_data_test.dart`

**Interfaces:**
- Consumes: `IssueStatus`, `IssuePriority` from `lib/features/lead_cockpit/data/models/cockpit_data.dart`.
- Produces:
  - `enum BoardItemType { issue, pullRequest }`
  - `enum PrCiState { passing, failing, pending, none }`
  - `enum PrReviewState { approved, changesRequested, review, none }`
  - `BoardCard` (Freezed, `fromJson`): `String id; BoardItemType type; String repo; int number; String title; @Default(false) bool isDraft; IssueStatus status; IssuePriority? priority; int? points; int? subDone; int? subTotal; int? staleDays; @Default(<String>[]) List<String> assignees; PrCiState? ciState; PrReviewState? reviewState; String? owner;`
  - `ColumnFacts` (Freezed, no `fromJson`): `@Default(0) int p0Unowned; @Default(0) int missingEstimate; @Default(0) int stuckCount; @Default(<int>[]) List<int> ciRedNumbers;` with getter `bool get isEmpty => p0Unowned==0 && missingEstimate==0 && stuckCount==0 && ciRedNumbers.isEmpty;`
  - `BoardColumn` (Freezed, `fromJson`): `IssueStatus status; String label; @Default(<BoardCard>[]) List<BoardCard> cards; @ColumnFactsConverter()… ` — keep simple: `required ColumnFacts facts` is fine with `@JsonKey(includeFromJson:false,includeToJson:false)` since `ColumnFacts` has no json; mark it `@Default(ColumnFacts()) ColumnFacts facts` and exclude from json. `int get count => cards.length;`
  - `ProjectBoardData` (Freezed, `fromJson`): `required String title; @Default(<BoardColumn>[]) List<BoardColumn> columns;`
  - `const boardColumnOrder = <IssueStatus>[IssueStatus.triage, IssueStatus.notStarted, IssueStatus.inProgress, IssueStatus.inReview, IssueStatus.done];`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/data/models/board_data_test.dart
//
// Test summary:
// - BoardCard round-trips through JSON with PR fields.
// - ColumnFacts.isEmpty is true for the default and false when any count is set.
// - boardColumnOrder lists the five visible statuses in board order.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';

void main() {
  test('BoardCard round-trips through JSON', () {
    const card = BoardCard(
      id: 'p2',
      type: BoardItemType.pullRequest,
      repo: 'mobile-app',
      number: 482,
      title: 'Add biometric auth',
      status: IssueStatus.inProgress,
      priority: IssuePriority.p0,
      points: 8,
      assignees: ['tromero-tv'],
      ciState: PrCiState.passing,
      reviewState: PrReviewState.approved,
      owner: 'TurboVets',
    );
    expect(BoardCard.fromJson(card.toJson()), card);
  });

  test('ColumnFacts.isEmpty reflects whether any signal is present', () {
    expect(const ColumnFacts().isEmpty, isTrue);
    expect(const ColumnFacts(p0Unowned: 1).isEmpty, isFalse);
    expect(const ColumnFacts(ciRedNumbers: [155]).isEmpty, isFalse);
  });

  test('boardColumnOrder is the five visible statuses in order', () {
    expect(boardColumnOrder, [
      IssueStatus.triage,
      IssueStatus.notStarted,
      IssueStatus.inProgress,
      IssueStatus.inReview,
      IssueStatus.done,
    ]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects_board/data/models/board_data_test.dart`
Expected: FAIL — `board_data.dart` does not exist / no `BoardCard`.

- [ ] **Step 3: Write the model file**

```dart
// lib/features/projects_board/data/models/board_data.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../lead_cockpit/data/models/cockpit_data.dart';

part 'board_data.freezed.dart';
part 'board_data.g.dart';

/// Whether a board item is a GitHub Issue or a Pull Request.
enum BoardItemType { issue, pullRequest }

/// PR CI rollup, derived from `commits.statusCheckRollup.state`.
enum PrCiState { passing, failing, pending, none }

/// PR review decision, derived from `reviewDecision`.
enum PrReviewState { approved, changesRequested, review, none }

/// One card on the board (issue or PR), already flattened from the GraphQL item.
@freezed
sealed class BoardCard with _$BoardCard {
  const BoardCard._();

  const factory BoardCard({
    required String id,
    required BoardItemType type,
    required String repo,
    required int number,
    required String title,
    @Default(false) bool isDraft,
    required IssueStatus status,
    IssuePriority? priority,
    int? points,
    int? subDone,
    int? subTotal,

    /// Days since last update once past the stuck threshold; null otherwise.
    int? staleDays,
    @Default(<String>[]) List<String> assignees,

    /// PR-only signals; null on issue cards.
    PrCiState? ciState,
    PrReviewState? reviewState,

    /// Repo owner login, used to build the PR-detail route on tap.
    String? owner,
  }) = _BoardCard;

  factory BoardCard.fromJson(Map<String, dynamic> json) => _$BoardCardFromJson(json);

  bool get isPr => type == BoardItemType.pullRequest;
  bool get hasSubIssues => (subTotal ?? 0) > 0;
  bool get isStale => staleDays != null;
}

/// Data-derived signal counts for one column — grounds the AI insight prompt.
@freezed
sealed class ColumnFacts with _$ColumnFacts {
  const ColumnFacts._();

  const factory ColumnFacts({
    @Default(0) int p0Unowned,
    @Default(0) int missingEstimate,
    @Default(0) int stuckCount,
    @Default(<int>[]) List<int> ciRedNumbers,
  }) = _ColumnFacts;

  bool get isEmpty => p0Unowned == 0 && missingEstimate == 0 && stuckCount == 0 && ciRedNumbers.isEmpty;
}

/// One Status column with its cards and derived facts.
@freezed
sealed class BoardColumn with _$BoardColumn {
  const BoardColumn._();

  const factory BoardColumn({
    required IssueStatus status,
    required String label,
    @Default(<BoardCard>[]) List<BoardCard> cards,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default(ColumnFacts()) ColumnFacts facts,
  }) = _BoardColumn;

  factory BoardColumn.fromJson(Map<String, dynamic> json) => _$BoardColumnFromJson(json);

  int get count => cards.length;
}

/// The whole board: title + ordered columns.
@freezed
sealed class ProjectBoardData with _$ProjectBoardData {
  const ProjectBoardData._();

  const factory ProjectBoardData({required String title, @Default(<BoardColumn>[]) List<BoardColumn> columns}) =
      _ProjectBoardData;

  factory ProjectBoardData.fromJson(Map<String, dynamic> json) => _$ProjectBoardDataFromJson(json);

  bool get hasAnyCards => columns.any((c) => c.cards.isNotEmpty);
}

/// The five statuses the board renders, in column order. `cancelled` is hidden.
const boardColumnOrder = <IssueStatus>[
  IssueStatus.triage,
  IssueStatus.notStarted,
  IssueStatus.inProgress,
  IssueStatus.inReview,
  IssueStatus.done,
];
```

- [ ] **Step 4: Generate code**

Run: `dart run build_runner build -d`
Expected: creates `board_data.freezed.dart` + `board_data.g.dart`, no errors.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/projects_board/data/models/board_data_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/projects_board/data/models/board_data.dart test/features/projects_board/data/models/board_data_test.dart
git commit -m "feat(projects-board): board data models"
```

---

### Task 2: Extend the ProjectV2 query for pull requests

**Files:**
- Modify: `lib/features/lead_cockpit/data/queries/project_board.dart`
- Test: `test/features/projects_board/data/queries/project_board_query_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `projectBoardQuery` now also selects `... on PullRequest { … }` (additive; the cockpit parser already ignores non-Issue content).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/data/queries/project_board_query_test.dart
//
// Test summary:
// - projectBoardQuery selects PullRequest content (isDraft, reviewDecision, CI rollup).
// - It still selects the Issue content the cockpit relies on.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/queries/project_board.dart';

void main() {
  test('query covers PullRequest content', () {
    expect(projectBoardQuery, contains('... on PullRequest'));
    expect(projectBoardQuery, contains('isDraft'));
    expect(projectBoardQuery, contains('reviewDecision'));
    expect(projectBoardQuery, contains('statusCheckRollup'));
  });

  test('query still covers Issue content', () {
    expect(projectBoardQuery, contains('... on Issue'));
    expect(projectBoardQuery, contains('subIssuesSummary'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects_board/data/queries/project_board_query_test.dart`
Expected: FAIL — query has no `PullRequest` branch yet.

- [ ] **Step 3: Add the PullRequest branch**

In `project_board.dart`, update the doc comment first line to mention PRs, then add the branch immediately after the existing `... on Issue { … }` block (inside `content { … }`):

```graphql
            ... on PullRequest {
              number
              title
              url
              isDraft
              state
              reviewDecision
              repository { name owner { login } }
              assignees(first: 5) { nodes { login } }
              commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
            }
```

Also add `owner { login }` to the existing Issue `repository { name }` so issue cards can build links:

```graphql
              repository { name owner { login } }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/projects_board/data/queries/project_board_query_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify the cockpit is unaffected**

Run: `flutter test test/features/lead_cockpit/data/repositories/cockpit_mapper_test.dart`
Expected: PASS (additive query change, parser still skips non-Issues).

- [ ] **Step 6: Commit**

```bash
git add lib/features/lead_cockpit/data/queries/project_board.dart test/features/projects_board/data/queries/project_board_query_test.dart
git commit -m "feat(projects-board): extend ProjectV2 query with PR content"
```

---

### Task 3: Board mapper

**Files:**
- Create: `lib/features/projects_board/data/repositories/board_mapper.dart`
- Test: `test/features/projects_board/data/repositories/board_mapper_test.dart`

**Interfaces:**
- Consumes: `BoardCard`, `BoardColumn`, `ColumnFacts`, `ProjectBoardData`, `boardColumnOrder` (Task 1); `IssueStatus`, `IssuePriority` (cockpit); `stuckAfterDays` from `lib/features/lead_cockpit/data/repositories/cockpit_mapper.dart`; `CockpitPalette.statusLabel` from `lib/features/lead_cockpit/presentation/helpers/cockpit_palette.dart`.
- Produces: `ProjectBoardData boardFromProjectItems(String title, List<Map<String, dynamic>> nodes, {required DateTime now})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/data/repositories/board_mapper_test.dart
//
// Test summary:
// - Parses an Issue item into a BoardCard with priority/points/sub-progress.
// - Parses a PullRequest item: CI rollup -> PrCiState, reviewDecision -> PrReviewState, isDraft.
// - Groups items into the five ordered columns; unknown/null status -> Not Started.
// - Drops cancelled items entirely.
// - Flags staleDays once past stuckAfterDays.
// - Computes ColumnFacts: p0Unowned, missingEstimate, stuckCount, ciRedNumbers.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/data/repositories/board_mapper.dart';

Map<String, dynamic> issueNode({
  required int number,
  required String title,
  String status = 'In Progress',
  String? priority,
  num? complexity,
  List<int>? sub,
  List<String> assignees = const [],
  String updatedAt = '2026-06-18T00:00:00Z',
}) => {
  'updatedAt': updatedAt,
  'content': {
    '__typename': 'Issue',
    'number': number,
    'title': title,
    'url': 'https://github.com/o/r/issues/$number',
    'repository': {'name': 'r', 'owner': {'login': 'o'}},
    'assignees': {'nodes': [for (final a in assignees) {'login': a}]},
    'subIssuesSummary': sub == null ? null : {'total': sub[1], 'completed': sub[0]},
  },
  'fieldValues': {
    'nodes': [
      {'__typename': 'ProjectV2ItemFieldSingleSelectValue', 'name': status, 'field': {'name': 'Status'}},
      if (priority != null)
        {'__typename': 'ProjectV2ItemFieldSingleSelectValue', 'name': priority, 'field': {'name': 'Priority'}},
      if (complexity != null)
        {'__typename': 'ProjectV2ItemFieldNumberValue', 'number': complexity, 'field': {'name': 'Complexity'}},
    ],
  },
};

Map<String, dynamic> prNode({
  required int number,
  required String title,
  String status = 'In Progress',
  String? ci,
  String? review,
  bool draft = false,
  String? priority,
}) => {
  'updatedAt': '2026-06-18T00:00:00Z',
  'content': {
    '__typename': 'PullRequest',
    'number': number,
    'title': title,
    'url': 'https://github.com/o/r/pull/$number',
    'isDraft': draft,
    'reviewDecision': review,
    'repository': {'name': 'r', 'owner': {'login': 'o'}},
    'assignees': {'nodes': []},
    'commits': {'nodes': [{'commit': {'statusCheckRollup': ci == null ? null : {'state': ci}}}]},
  },
  'fieldValues': {
    'nodes': [
      {'__typename': 'ProjectV2ItemFieldSingleSelectValue', 'name': status, 'field': {'name': 'Status'}},
      if (priority != null)
        {'__typename': 'ProjectV2ItemFieldSingleSelectValue', 'name': priority, 'field': {'name': 'Priority'}},
    ],
  },
};

BoardColumn columnFor(ProjectBoardData b, IssueStatus s) => b.columns.firstWhere((c) => c.status == s);

void main() {
  final now = DateTime.parse('2026-06-18T00:00:00Z');

  test('columns are the five board statuses in order', () {
    final b = boardFromProjectItems('Board', const [], now: now);
    expect(b.columns.map((c) => c.status).toList(), boardColumnOrder);
    expect(b.title, 'Board');
  });

  test('parses an issue card', () {
    final b = boardFromProjectItems('B', [
      issueNode(number: 1, title: 'Issue one', status: 'In Progress', priority: 'P2', complexity: 8, sub: [2, 5]),
    ], now: now);
    final card = columnFor(b, IssueStatus.inProgress).cards.single;
    expect(card.type, BoardItemType.issue);
    expect(card.number, 1);
    expect(card.priority, IssuePriority.p2);
    expect(card.points, 8);
    expect(card.subDone, 2);
    expect(card.subTotal, 5);
    expect(card.owner, 'o');
  });

  test('parses a PR card with CI, review, draft', () {
    final b = boardFromProjectItems('B', [
      prNode(number: 9, title: 'PR nine', ci: 'FAILURE', review: 'CHANGES_REQUESTED', draft: true),
    ], now: now);
    final card = columnFor(b, IssueStatus.inProgress).cards.single;
    expect(card.type, BoardItemType.pullRequest);
    expect(card.ciState, PrCiState.failing);
    expect(card.reviewState, PrReviewState.changesRequested);
    expect(card.isDraft, isTrue);
  });

  test('unknown status buckets into Not Started; cancelled is dropped', () {
    final b = boardFromProjectItems('B', [
      issueNode(number: 2, title: 'No status', status: 'Frobnicate'),
      issueNode(number: 3, title: 'Cancelled', status: 'Cancelled'),
    ], now: now);
    expect(columnFor(b, IssueStatus.notStarted).cards.single.number, 2);
    expect(b.columns.every((c) => c.cards.every((x) => x.number != 3)), isTrue);
  });

  test('flags staleDays past the threshold', () {
    final old = now.subtract(Duration(days: stuckAfterDays + 2)).toIso8601String();
    final b = boardFromProjectItems('B', [
      issueNode(number: 4, title: 'Old', updatedAt: old),
    ], now: now);
    expect(columnFor(b, IssueStatus.inProgress).cards.single.staleDays, stuckAfterDays + 2);
  });

  test('computes column facts', () {
    final b = boardFromProjectItems('B', [
      issueNode(number: 5, title: 'P0 unowned', priority: 'P0'),            // p0Unowned, missingEstimate
      prNode(number: 6, title: 'Red CI', ci: 'FAILURE', priority: 'P1'),    // ciRed, missingEstimate
    ], now: now);
    final facts = columnFor(b, IssueStatus.inProgress).facts;
    expect(facts.p0Unowned, 1);
    expect(facts.missingEstimate, 2);
    expect(facts.ciRedNumbers, [6]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects_board/data/repositories/board_mapper_test.dart`
Expected: FAIL — `board_mapper.dart` missing.

- [ ] **Step 3: Write the mapper**

```dart
// lib/features/projects_board/data/repositories/board_mapper.dart
//
// Pure transform from raw ProjectV2 `items.nodes` into ProjectBoardData.
// IO-free so it unit-tests with fixture JSON. Handles both Issue and
// PullRequest content; cancelled items are dropped and unknown statuses fall
// into Not Started.
import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../lead_cockpit/data/repositories/cockpit_mapper.dart' show stuckAfterDays;
import '../../../lead_cockpit/presentation/helpers/cockpit_palette.dart';
import '../models/board_data.dart';

ProjectBoardData boardFromProjectItems(String title, List<Map<String, dynamic>> nodes, {required DateTime now}) {
  final cards = nodes.map((n) => _parseCard(n, now)).whereType<BoardCard>().toList();

  final columns = <BoardColumn>[];
  for (final status in boardColumnOrder) {
    final inCol = cards.where((c) => c.status == status).toList();
    columns.add(
      BoardColumn(
        status: status,
        label: CockpitPalette.statusLabel(status),
        cards: inCol,
        facts: _factsFor(inCol),
      ),
    );
  }
  return ProjectBoardData(title: title, columns: columns);
}

ColumnFacts _factsFor(List<BoardCard> cards) => ColumnFacts(
  p0Unowned: cards.where((c) => c.priority == IssuePriority.p0 && c.assignees.isEmpty).length,
  missingEstimate: cards.where((c) => c.points == null).length,
  stuckCount: cards.where((c) => c.isStale).length,
  ciRedNumbers: cards.where((c) => c.ciState == PrCiState.failing).map((c) => c.number).toList(),
);

BoardCard? _parseCard(Map<String, dynamic> node, DateTime now) {
  final content = node['content'];
  if (content is! Map<String, dynamic>) return null;
  final typename = content['__typename'];
  final isPr = typename == 'PullRequest';
  if (typename != 'Issue' && !isPr) return null;

  // Field values (Status / Priority / Complexity).
  IssueStatus? status;
  IssuePriority? priority;
  num? complexity;
  for (final raw in (node['fieldValues']?['nodes'] as List<dynamic>?) ?? const []) {
    if (raw is! Map<String, dynamic>) continue;
    final fieldName = (raw['field']?['name'] as String?)?.toLowerCase() ?? '';
    switch (raw['__typename']) {
      case 'ProjectV2ItemFieldSingleSelectValue':
        final value = raw['name'] as String?;
        if (fieldName == 'status') {
          status = _statusFrom(value);
        } else if (fieldName == 'priority') {
          priority = _priorityFrom(value);
        }
      case 'ProjectV2ItemFieldNumberValue':
        if (fieldName == 'complexity') complexity = raw['number'] as num?;
    }
  }
  if (status == IssueStatus.cancelled) return null;

  final repo = content['repository']?['name'] as String? ?? '';
  final owner = content['repository']?['owner']?['login'] as String?;
  final assignees = ((content['assignees']?['nodes'] as List<dynamic>?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map((a) => a['login'] as String?)
      .whereType<String>()
      .toList();
  final sub = content['subIssuesSummary'];
  final subTotal = sub is Map<String, dynamic> ? (sub['total'] as num?)?.toInt() : null;
  final subDone = sub is Map<String, dynamic> ? (sub['completed'] as num?)?.toInt() : null;

  final updatedAt =
      DateTime.tryParse((node['updatedAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  final age = now.difference(updatedAt).inDays.clamp(0, 9999);

  return BoardCard(
    id: '$owner/$repo#${(content['number'] as num?)?.toInt() ?? 0}',
    type: isPr ? BoardItemType.pullRequest : BoardItemType.issue,
    repo: repo,
    number: (content['number'] as num?)?.toInt() ?? 0,
    title: (content['title'] as String?) ?? '',
    isDraft: isPr && (content['isDraft'] as bool? ?? false),
    status: status ?? IssueStatus.notStarted,
    priority: priority,
    points: complexity?.round(),
    subDone: subDone,
    subTotal: subTotal,
    staleDays: age >= stuckAfterDays ? age : null,
    assignees: assignees,
    ciState: isPr ? _ciFrom(content) : null,
    reviewState: isPr ? _reviewFrom(content['reviewDecision'] as String?) : null,
    owner: owner,
  );
}

PrCiState _ciFrom(Map<String, dynamic> content) {
  final nodes = content['commits']?['nodes'] as List<dynamic>?;
  final state = (nodes?.firstOrNull as Map<String, dynamic>?)?['commit']?['statusCheckRollup']?['state'] as String?;
  return switch (state) {
    'SUCCESS' => PrCiState.passing,
    'FAILURE' || 'ERROR' => PrCiState.failing,
    'PENDING' || 'EXPECTED' => PrCiState.pending,
    _ => PrCiState.none,
  };
}

PrReviewState _reviewFrom(String? decision) => switch (decision) {
  'APPROVED' => PrReviewState.approved,
  'CHANGES_REQUESTED' => PrReviewState.changesRequested,
  'REVIEW_REQUIRED' => PrReviewState.review,
  _ => PrReviewState.none,
};

IssueStatus? _statusFrom(String? name) {
  final n = name?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (n == null || n.isEmpty) return null;
  return switch (n) {
    'not started' || 'backlog' || 'to do' || 'todo' || 'new' || 'open' => IssueStatus.notStarted,
    'in progress' || 'doing' || 'wip' || 'started' || 'in dev' || 'development' => IssueStatus.inProgress,
    'in review' || 'review' || 'code review' || 'in qa' || 'qa' || 'testing' => IssueStatus.inReview,
    'triage' || 'needs triage' || 'blocked' || 'on hold' => IssueStatus.triage,
    'done' || 'closed' || 'shipped' || 'complete' || 'completed' || 'merged' => IssueStatus.done,
    'cancelled' || 'canceled' || "won't do" || 'wont do' || 'duplicate' || 'invalid' => IssueStatus.cancelled,
    _ => null,
  };
}

IssuePriority? _priorityFrom(String? name) {
  final n = name?.trim().toLowerCase();
  if (n == null || n.isEmpty) return null;
  return switch (n) {
    'p0' || 'critical' || 'urgent' || 'highest' => IssuePriority.p0,
    'p1' || 'high' => IssuePriority.p1,
    'p2' || 'medium' || 'normal' => IssuePriority.p2,
    'p3' || 'low' || 'lowest' => IssuePriority.p3,
    _ => null,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/projects_board/data/repositories/board_mapper_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects_board/data/repositories/board_mapper.dart test/features/projects_board/data/repositories/board_mapper_test.dart
git commit -m "feat(projects-board): pure board mapper for issues and PRs"
```

---

### Task 4: Board repository (interface + Github + Mock)

**Files:**
- Create: `lib/features/projects_board/data/repositories/projects_board_repository.dart`
- Test: `test/features/projects_board/data/repositories/projects_board_repository_test.dart`

**Interfaces:**
- Consumes: `GithubApiClient` (`lib/features/repo_setup/data/services/github_api_client.dart`), `projectBoardQuery`, `boardFromProjectItems`, `ProjectBoardData`, turbo_core `Result`.
- Produces:
  - `abstract class ProjectsBoardRepository { Future<Result<ProjectBoardData>> fetchBoard(); }`
  - `class GithubProjectsBoardRepository implements ProjectsBoardRepository` — ctor `(GithubApiClient client, {required String org, required int projectNumber, DateTime Function()? clock})`.
  - `class MockProjectsBoardRepository implements ProjectsBoardRepository` — returns the design sample (`sampleBoard`), exported for widget tests.
  - `ProjectBoardData get sampleBoard` (top-level const-ish builder) seeded with the `Projects Board.dc.html` cards.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/data/repositories/projects_board_repository_test.dart
//
// Test summary:
// - MockProjectsBoardRepository returns a success with the five ordered columns.
// - The sample board has cards (so widget tests have content to render).
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/data/repositories/projects_board_repository.dart';

void main() {
  test('mock repo returns the ordered columns', () async {
    final result = await const MockProjectsBoardRepository().fetchBoard();
    final data = result.dataOrNull!;
    expect(data.columns.map((c) => c.status).toList(), boardColumnOrder);
    expect(data.hasAnyCards, isTrue);
  });
}
```

> If `Result` has no `dataOrNull`, switch to `result.when(success: (d) => d, failure: (m, _) => fail(m))`. Confirm by reading `turbo_core`'s `Result` first.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects_board/data/repositories/projects_board_repository_test.dart`
Expected: FAIL — repository missing.

- [ ] **Step 3: Write the repository**

```dart
// lib/features/projects_board/data/repositories/projects_board_repository.dart
import 'dart:developer';

import 'package:turbo_core/core.dart';

import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../lead_cockpit/data/queries/project_board.dart';
import '../../../repo_setup/data/services/github_api_client.dart';
import '../models/board_data.dart';
import 'board_mapper.dart';

/// Data access for the Projects Board (read-only ProjectV2 board).
abstract class ProjectsBoardRepository {
  Future<Result<ProjectBoardData>> fetchBoard();
}

/// Reads a live org ProjectV2 board and maps it to [ProjectBoardData].
/// Mirrors GithubLeadCockpitRepository's pagination loop.
class GithubProjectsBoardRepository implements ProjectsBoardRepository {
  GithubProjectsBoardRepository(this._client, {required this.org, required this.projectNumber, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final GithubApiClient _client;
  final String org;
  final int projectNumber;
  final DateTime Function() _clock;

  static const int _pageSize = 100;
  static const int _maxPages = 10;

  @override
  Future<Result<ProjectBoardData>> fetchBoard() async {
    try {
      final nodes = <Map<String, dynamic>>[];
      String? boardTitle;
      String? after;
      for (var page = 0; page < _maxPages; page++) {
        final data = await _client.graphql(projectBoardQuery, {
          'org': org,
          'number': projectNumber,
          'first': _pageSize,
          'after': after,
        });
        final project = data['organization']?['projectV2'] as Map<String, dynamic>?;
        if (project == null) {
          return Result.failure('No access to project #$projectNumber in $org.', StackTrace.current);
        }
        boardTitle ??= project['title'] as String?;
        final items = project['items'] as Map<String, dynamic>?;
        nodes.addAll(((items?['nodes'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>());
        final pageInfo = items?['pageInfo'] as Map<String, dynamic>?;
        if ((pageInfo?['hasNextPage'] as bool?) != true) break;
        after = pageInfo?['endCursor'] as String?;
        if (after == null) break;
      }
      return Result.success(boardFromProjectItems(boardTitle ?? 'Project board', nodes, now: _clock()));
    } catch (e, stackTrace) {
      log('Failed to fetch board', error: e, stackTrace: stackTrace);
      return Result.failure(_scopeAwareMessage(e, 'Failed to load the project board'), stackTrace);
    }
  }

  String _scopeAwareMessage(Object e, String fallback) => e.toString().contains('read:project')
      ? 'Your GitHub token is missing the `read:project` scope. Add it at '
            'github.com/settings/tokens, then re-enter the token in Settings.'
      : fallback;
}

/// In-memory board seeded with the design sample, for tests and tokenless runs.
class MockProjectsBoardRepository implements ProjectsBoardRepository {
  const MockProjectsBoardRepository();

  @override
  Future<Result<ProjectBoardData>> fetchBoard() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Result.success(sampleBoard);
  }
}

BoardColumn _col(IssueStatus status, String label, List<BoardCard> cards) =>
    BoardColumn(status: status, label: label, cards: cards);

/// Sample board from `Projects Board.dc.html` (In Progress is the varied column).
final ProjectBoardData sampleBoard = ProjectBoardData(
  title: 'Mobile Q3 Roadmap',
  columns: [
    _col(IssueStatus.triage, 'Triage', const [
      BoardCard(id: 'o/api-gateway#301', type: BoardItemType.issue, owner: 'o', repo: 'api-gateway', number: 301,
          title: 'Investigate elevated 504s on /sync between 2–4am UTC', status: IssueStatus.triage, priority: IssuePriority.p0),
      BoardCard(id: 'o/web-portal#488', type: BoardItemType.issue, owner: 'o', repo: 'web-portal', number: 488,
          title: 'Billing export CSV missing tax column for EU accounts', status: IssueStatus.triage, priority: IssuePriority.p2, assignees: ['apatel-tv']),
    ]),
    _col(IssueStatus.notStarted, 'Not Started', const [
      BoardCard(id: 'o/mobile-app#598', type: BoardItemType.issue, owner: 'o', repo: 'mobile-app', number: 598,
          title: 'Add offline draft autosave to compose screen', status: IssueStatus.notStarted, priority: IssuePriority.p2, points: 8, subDone: 0, subTotal: 5, assignees: ['tromero-tv']),
    ]),
    _col(IssueStatus.inProgress, 'In Progress', const [
      BoardCard(id: 'o/mobile-app#571', type: BoardItemType.issue, owner: 'o', repo: 'mobile-app', number: 571,
          title: 'Biometric re-auth flow for sensitive actions', status: IssueStatus.inProgress, priority: IssuePriority.p0, points: 13, subDone: 3, subTotal: 7, assignees: ['tromero-tv', 'mkim-tv']),
      BoardCard(id: 'o/mobile-app#482', type: BoardItemType.pullRequest, owner: 'o', repo: 'mobile-app', number: 482,
          title: 'Add biometric auth to login flow', status: IssueStatus.inProgress, priority: IssuePriority.p0, points: 8, ciState: PrCiState.passing, reviewState: PrReviewState.approved, assignees: ['tromero-tv']),
      BoardCard(id: 'o/web-portal#155', type: BoardItemType.pullRequest, owner: 'o', repo: 'web-portal', number: 155,
          title: 'Migrate auth context to React Server Components', status: IssueStatus.inProgress, priority: IssuePriority.p1, points: 5, ciState: PrCiState.failing, reviewState: PrReviewState.changesRequested, staleDays: 6, assignees: ['apatel-tv', 'snguyen-tv']),
      BoardCard(id: 'o/design-system#86', type: BoardItemType.pullRequest, owner: 'o', repo: 'design-system', number: 86,
          title: 'Deprecate legacy button variants ahead of v3', status: IssueStatus.inProgress, priority: IssuePriority.p3, isDraft: true, ciState: PrCiState.pending, reviewState: PrReviewState.review, assignees: ['lbarros-tv']),
    ]),
    _col(IssueStatus.inReview, 'In Review', const [
      BoardCard(id: 'o/api-gateway#299', type: BoardItemType.pullRequest, owner: 'o', repo: 'api-gateway', number: 299,
          title: 'Connection pool tuning for read replicas', status: IssueStatus.inReview, priority: IssuePriority.p1, points: 5, ciState: PrCiState.passing, reviewState: PrReviewState.review, assignees: ['snguyen-tv']),
    ]),
    _col(IssueStatus.done, 'Done', const [
      BoardCard(id: 'o/mobile-app#470', type: BoardItemType.pullRequest, owner: 'o', repo: 'mobile-app', number: 470,
          title: 'Fix cold-start crash on Android 13', status: IssueStatus.done, priority: IssuePriority.p0, points: 3, ciState: PrCiState.passing, reviewState: PrReviewState.approved, assignees: ['tromero-tv']),
    ]),
  ],
);
```

> Before writing, confirm `Result.success`/`Result.failure` and the accessor used in the test (`dataOrNull` or `.when`) against `turbo_core`'s `core.dart`. Use whatever the cockpit repo uses.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/projects_board/data/repositories/projects_board_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects_board/data/repositories/projects_board_repository.dart test/features/projects_board/data/repositories/projects_board_repository_test.dart
git commit -m "feat(projects-board): board repository (github + mock + sample)"
```

---

### Task 5: AI column-insights (prompt, parser, repo method)

**Files:**
- Modify: `lib/features/ai/presentation/helpers/ai_prompts.dart` (add `buildBoardInsightsPrompt` + `parseBoardInsights`)
- Modify: `lib/features/ai/data/repositories/ai_repository.dart` (interface + impl)
- Test: `test/features/projects_board/data/ai_board_insights_test.dart`

**Interfaces:**
- Consumes: `ProjectBoardData`, `BoardColumn`, `ColumnFacts`, `IssueStatus`, `CockpitPalette.statusLabel`, `AnthropicApiClient.complete`.
- Produces:
  - `String buildBoardInsightsPrompt(ProjectBoardData board)`
  - `Map<IssueStatus, String> parseBoardInsights(String text)`
  - `AiRepository.boardInsights(ProjectBoardData board) -> Future<Result<Map<IssueStatus, String>>>`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/data/ai_board_insights_test.dart
//
// Test summary:
// - buildBoardInsightsPrompt embeds each non-empty column's facts and asks for JSON.
// - parseBoardInsights decodes a JSON object keyed by status label into IssueStatus.
// - parseBoardInsights tolerates surrounding prose and drops empty/unknown keys.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';

void main() {
  test('prompt includes facts and requests JSON', () {
    final board = ProjectBoardData(title: 'B', columns: [
      const BoardColumn(status: IssueStatus.inProgress, label: 'In Progress',
          facts: ColumnFacts(p0Unowned: 1, stuckCount: 2, ciRedNumbers: [155])),
    ]);
    final prompt = buildBoardInsightsPrompt(board);
    expect(prompt, contains('In Progress'));
    expect(prompt, contains('JSON'));
    expect(prompt, contains('155'));
  });

  test('parses JSON object embedded in prose', () {
    const text = 'Here you go:\n{"In Progress":"2 stuck >4d · CI red on #155","Done":""}\nThanks';
    final map = parseBoardInsights(text);
    expect(map[IssueStatus.inProgress], '2 stuck >4d · CI red on #155');
    expect(map.containsKey(IssueStatus.done), isFalse); // empty dropped
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects_board/data/ai_board_insights_test.dart`
Expected: FAIL — functions missing.

- [ ] **Step 3: Add prompt + parser**

Append to `lib/features/ai/presentation/helpers/ai_prompts.dart` (it already imports `cockpit_data.dart`; add `import '../../../projects_board/data/models/board_data.dart';` and `import '../../../lead_cockpit/presentation/helpers/cockpit_palette.dart';`):

```dart
/// One-line-per-column board insight prompt. Grounded in derived facts (not raw
/// cards) so it stays cheap and deterministic. Asks for a JSON object keyed by
/// the column's display label.
String buildBoardInsightsPrompt(ProjectBoardData board) {
  final lines = <String>[];
  for (final col in board.columns) {
    if (col.facts.isEmpty) continue;
    final f = col.facts;
    final parts = <String>[
      if (f.p0Unowned > 0) '${f.p0Unowned} P0 unowned',
      if (f.missingEstimate > 0) '${f.missingEstimate} missing estimate',
      if (f.stuckCount > 0) '${f.stuckCount} stuck',
      if (f.ciRedNumbers.isNotEmpty) 'CI failing on #${f.ciRedNumbers.join(", #")}',
    ];
    lines.add('${col.label} (${col.count} items): ${parts.join("; ")}');
  }
  final facts = lines.isEmpty ? '(no notable signals)' : lines.join('\n');
  return '''
You are triaging a GitHub project board. For each column below, write ONE terse insight line (max ~8 words) a tech lead would care about — what is stuck, unowned, unestimated, or failing CI. Use the exact "·"-separated style, e.g. "2 stuck >4d · 1 P0 blocking · CI red on #155".

Return ONLY a JSON object mapping the column name to its line. Omit columns with nothing notable.

Columns and signals:
$facts
''';
}

/// Parses the model's JSON object (possibly wrapped in prose) into a status map.
/// Keys are matched to [IssueStatus] by display label; empty values are dropped.
Map<IssueStatus, String> parseBoardInsights(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return const {};
  Map<String, dynamic> raw;
  try {
    raw = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (_) {
    return const {};
  }
  final byLabel = {for (final s in IssueStatus.values) CockpitPalette.statusLabel(s).toLowerCase(): s};
  final out = <IssueStatus, String>{};
  raw.forEach((key, value) {
    final status = byLabel[key.trim().toLowerCase()];
    final line = value?.toString().trim() ?? '';
    if (status != null && line.isNotEmpty) out[status] = line;
  });
  return out;
}
```

- [ ] **Step 4: Add the repo method (interface + impl)**

In `ai_repository.dart`, add `import '../../projects_board/data/models/board_data.dart';`, then to the `AiRepository` interface:

```dart
  /// Per-column one-line board insights, keyed by status. Empty map if nothing notable.
  Future<Result<Map<IssueStatus, String>>> boardInsights(ProjectBoardData board);
```

And to `AnthropicAiRepository`:

```dart
  @override
  Future<Result<Map<IssueStatus, String>>> boardInsights(ProjectBoardData board) async {
    try {
      final text = await _anthropic.complete(prompt: buildBoardInsightsPrompt(board), maxTokens: 400);
      return Result.success(parseBoardInsights(text));
    } catch (e, stackTrace) {
      log('Failed to generate board insights', error: e, stackTrace: stackTrace);
      return Result.failure('Could not generate board insights.', stackTrace);
    }
  }
```

(Add `import '../../lead_cockpit/data/models/cockpit_data.dart';` if not already present — it is, via the existing cockpit import.)

- [ ] **Step 5: Regenerate mockito mocks (interface changed)**

Run: `dart run build_runner build -d`
Expected: `ai_repository_test.mocks.dart` regenerates with `boardInsights` stubbed; existing AI tests still compile.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/projects_board/data/ai_board_insights_test.dart test/features/ai`
Expected: PASS (new file + existing AI tests unaffected).

- [ ] **Step 7: Commit**

```bash
git add lib/features/ai test/features/projects_board/data/ai_board_insights_test.dart
git commit -m "feat(projects-board): on-demand AI board-insights prompt + repo method"
```

---

### Task 6: Board palette helper

**Files:**
- Create: `lib/features/projects_board/presentation/helpers/board_palette.dart`
- Test: `test/features/projects_board/presentation/board_palette_test.dart`

**Interfaces:**
- Consumes: `IssueStatus`, `PrCiState`, `PrReviewState`, `TbColors`.
- Produces: `BoardPalette.columnAccent(IssueStatus)`, `BoardPalette.ciDot(PrCiState)`, `BoardPalette.reviewDot(PrReviewState)` → `Color`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/presentation/board_palette_test.dart
//
// Test summary:
// - columnAccent matches the mockup's per-status accent colors.
// - ciDot / reviewDot map states to the design's signal colors.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/helpers/board_palette.dart';

void main() {
  test('column accents match the mockup', () {
    expect(BoardPalette.columnAccent(IssueStatus.inProgress), const Color(0xFF0073FF));
    expect(BoardPalette.columnAccent(IssueStatus.done), const Color(0xFF54AE39));
    expect(BoardPalette.columnAccent(IssueStatus.triage), const Color(0xFFBABBBF));
  });

  test('ci and review dots map to signal colors', () {
    expect(BoardPalette.ciDot(PrCiState.failing), const Color(0xFFE94A5F));
    expect(BoardPalette.ciDot(PrCiState.passing), const Color(0xFF54AE39));
    expect(BoardPalette.reviewDot(PrReviewState.changesRequested), const Color(0xFFE94A5F));
    expect(BoardPalette.reviewDot(PrReviewState.none), const Color(0xFF45454C));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects_board/presentation/board_palette_test.dart`
Expected: FAIL — helper missing.

- [ ] **Step 3: Write the helper**

```dart
// lib/features/projects_board/presentation/helpers/board_palette.dart
import 'package:flutter/widgets.dart';

import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../data/models/board_data.dart';

/// Board-specific colors: column top accents and PR CI/review dots.
/// Verbatim from `Projects Board.dc.html`.
abstract final class BoardPalette {
  static Color columnAccent(IssueStatus status) => switch (status) {
    IssueStatus.triage => const Color(0xFFBABBBF),
    IssueStatus.notStarted => const Color(0xFF6E6E76),
    IssueStatus.inProgress => const Color(0xFF0073FF),
    IssueStatus.inReview => const Color(0xFFFFB000),
    IssueStatus.done => const Color(0xFF54AE39),
    IssueStatus.cancelled => const Color(0xFF45454C),
  };

  static Color ciDot(PrCiState state) => switch (state) {
    PrCiState.passing => const Color(0xFF54AE39),
    PrCiState.failing => const Color(0xFFE94A5F),
    PrCiState.pending => const Color(0xFFFFB000),
    PrCiState.none => const Color(0xFF45454C),
  };

  static Color reviewDot(PrReviewState state) => switch (state) {
    PrReviewState.approved => const Color(0xFF54AE39),
    PrReviewState.changesRequested => const Color(0xFFE94A5F),
    PrReviewState.review => const Color(0xFFBABBBF),
    PrReviewState.none => const Color(0xFF45454C),
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/projects_board/presentation/board_palette_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects_board/presentation/helpers/board_palette.dart test/features/projects_board/presentation/board_palette_test.dart
git commit -m "feat(projects-board): board palette (accents + PR dots)"
```

---

### Task 7: Providers (repo, board future, insights controller)

**Files:**
- Create: `lib/features/projects_board/presentation/providers/projects_board_provider.dart`
- Test: `test/features/projects_board/presentation/providers/projects_board_provider_test.dart`

**Interfaces:**
- Consumes: `githubApiClientProvider` (`lib/features/repo_setup/presentation/providers/auth_provider.dart`), `selectedProjectProvider` (`lib/features/lead_cockpit/presentation/providers/lead_cockpit_provider.dart`), `aiRepositoryProvider` (`lib/features/ai/presentation/providers/ai_provider.dart`), `ProjectsBoardRepository`/`GithubProjectsBoardRepository`, `ProjectBoardData`, `IssueStatus`.
- Produces:
  - `projectsBoardRepositoryProvider` (keepAlive) → `ProjectsBoardRepository`
  - `projectsBoardProvider` (autodispose Future) → `ProjectBoardData`
  - `BoardInsightsController` (`boardInsightsControllerProvider`) → `AsyncValue<Map<IssueStatus, String>>?` with `generate(ProjectBoardData)` + `clear()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/presentation/providers/projects_board_provider_test.dart
//
// Test summary:
// - projectsBoardProvider yields the repo's board on success.
// - projectsBoardProvider throws (AsyncError) on repo failure.
// - BoardInsightsController: null -> loading -> data on generate; error path; clear() resets to null.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:turbo_core/core.dart';
import 'package:turbo_board/features/ai/data/repositories/ai_repository.dart';
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/data/repositories/projects_board_repository.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';

import 'projects_board_provider_test.mocks.dart';

class _FailRepo implements ProjectsBoardRepository {
  @override
  Future<Result<ProjectBoardData>> fetchBoard() async => Result.failure('boom', StackTrace.current);
}

@GenerateMocks([AiRepository])
void main() {
  test('board provider yields the repo board', () async {
    final c = ProviderContainer(overrides: [
      projectsBoardRepositoryProvider.overrideWithValue(const MockProjectsBoardRepository()),
    ]);
    addTearDown(c.dispose);
    final data = await c.read(projectsBoardProvider.future);
    expect(data.columns, isNotEmpty);
  });

  test('board provider surfaces failure as error', () async {
    final c = ProviderContainer(overrides: [
      projectsBoardRepositoryProvider.overrideWithValue(_FailRepo()),
    ]);
    addTearDown(c.dispose);
    await expectLater(c.read(projectsBoardProvider.future), throwsA(isA<Exception>()));
  });

  test('insights controller: generate then clear', () async {
    final ai = MockAiRepository();
    when(ai.boardInsights(any)).thenAnswer((_) async => Result.success({IssueStatus.inProgress: 'all good'}));
    final c = ProviderContainer(overrides: [aiRepositoryProvider.overrideWithValue(ai)]);
    addTearDown(c.dispose);

    expect(c.read(boardInsightsControllerProvider), isNull);
    await c.read(boardInsightsControllerProvider.notifier).generate(const ProjectBoardData(title: 'B'));
    expect(c.read(boardInsightsControllerProvider)!.value, {IssueStatus.inProgress: 'all good'});
    c.read(boardInsightsControllerProvider.notifier).clear();
    expect(c.read(boardInsightsControllerProvider), isNull);
  });
}
```

- [ ] **Step 2: Write the provider, then generate**

```dart
// lib/features/projects_board/presentation/providers/projects_board_provider.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../ai/presentation/providers/ai_provider.dart';
import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../data/models/board_data.dart';
import '../../data/repositories/projects_board_repository.dart';

part 'projects_board_provider.g.dart';

@Riverpod(keepAlive: true)
ProjectsBoardRepository projectsBoardRepository(Ref ref) {
  final client = ref.watch(githubApiClientProvider);
  final selected = ref.watch(selectedProjectProvider);
  return GithubProjectsBoardRepository(client, org: selected?.owner ?? '', projectNumber: selected?.number ?? 0);
}

@riverpod
Future<ProjectBoardData> projectsBoard(Ref ref) async {
  final result = await ref.watch(projectsBoardRepositoryProvider).fetchBoard();
  return result.when(
    success: (data) {
      if (ref.mounted) ref.keepAlive();
      return data;
    },
    failure: (message, _) => throw Exception(message),
  );
}

/// On-demand AI column insights. `null` = not requested yet (mirrors the cockpit
/// brief / PR summary controllers). Never auto-fires.
@riverpod
class BoardInsightsController extends _$BoardInsightsController {
  @override
  AsyncValue<Map<IssueStatus, String>>? build() => null;

  Future<void> generate(ProjectBoardData board) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).boardInsights(board);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}
```

Run: `dart run build_runner build -d`
Expected: generates `projects_board_provider.g.dart` and the test's `.mocks.dart`.

> Confirm `result.when(success:/failure:)` and the `ResultSuccess`/`ResultFailure` pattern names against `turbo_core` (the cockpit provider uses both forms — copy its style).

- [ ] **Step 3: Run test to verify it fails then passes**

Run: `flutter test test/features/projects_board/presentation/providers/projects_board_provider_test.dart`
Expected: PASS (3 tests) after build_runner. (If run before build_runner: FAIL on missing generated files.)

- [ ] **Step 4: Commit**

```bash
git add lib/features/projects_board/presentation/providers/projects_board_provider.dart test/features/projects_board/presentation/providers/projects_board_provider_test.dart
git commit -m "feat(projects-board): providers (repo, board future, insights controller)"
```

---

### Task 8: Board card widget

**Files:**
- Create: `lib/features/projects_board/presentation/view/widgets/board_card.dart`
- Test: `test/features/projects_board/presentation/widgets/board_card_test.dart`

**Interfaces:**
- Consumes: `BoardCard`, `BoardItemType`, `CockpitPalette` (priority signal/label), `BoardPalette` (ci/review dots), `TbBadge`, `TbSignalDot`, `TbAvatarTile`, `TbColors`, `TbText`, `TbRepoColor`.
- Produces: `class BoardCardTile extends StatelessWidget { const BoardCardTile({required this.card, required this.onTap}); final BoardCard card; final VoidCallback onTap; }`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/presentation/widgets/board_card_test.dart
//
// Test summary:
// - Renders title, repo, #number and the priority badge.
// - PR card shows CI + Rev dots; draft PR shows the Draft badge.
// - Issue card shows neither CI/Rev dots nor Draft.
// - Tapping invokes onTap.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/view/widgets/board_card.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('PR draft card shows draft badge, CI and Rev dots', (tester) async {
    await tester.pumpWidget(_host(BoardCardTile(
      card: const BoardCard(id: 'o/r#86', type: BoardItemType.pullRequest, owner: 'o', repo: 'design-system',
          number: 86, title: 'Deprecate legacy buttons', status: IssueStatus.inProgress, priority: IssuePriority.p3,
          isDraft: true, ciState: PrCiState.pending, reviewState: PrReviewState.review),
      onTap: () {},
    )));
    expect(find.text('Deprecate legacy buttons'), findsOneWidget);
    expect(find.text('#86'), findsOneWidget);
    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.text('CI'), findsOneWidget);
    expect(find.text('REV'), findsOneWidget);
  });

  testWidgets('issue card has no CI/Rev or draft', (tester) async {
    await tester.pumpWidget(_host(BoardCardTile(
      card: const BoardCard(id: 'o/r#301', type: BoardItemType.issue, owner: 'o', repo: 'api-gateway', number: 301,
          title: 'Investigate 504s', status: IssueStatus.triage, priority: IssuePriority.p0),
      onTap: () {},
    )));
    expect(find.text('CI'), findsNothing);
    expect(find.text('DRAFT'), findsNothing);
    expect(find.text('P0'), findsOneWidget);
  });

  testWidgets('tap fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(BoardCardTile(
      card: const BoardCard(id: 'o/r#1', type: BoardItemType.issue, owner: 'o', repo: 'r', number: 1,
          title: 'X', status: IssueStatus.done, priority: IssuePriority.p2),
      onTap: () => tapped = true,
    )));
    await tester.tap(find.byType(BoardCardTile));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects_board/presentation/widgets/board_card_test.dart`
Expected: FAIL — widget missing.

- [ ] **Step 3: Write the widget**

```dart
// lib/features/projects_board/presentation/view/widgets/board_card.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../lead_cockpit/presentation/helpers/cockpit_palette.dart';
import '../../../data/models/board_data.dart';
import '../../helpers/board_palette.dart';

/// A single board card (issue or PR), matching `Projects Board.dc.html`.
class BoardCardTile extends StatelessWidget {
  const BoardCardTile({super.key, required this.card, required this.onTap});

  final BoardCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = card.priority == IssuePriority.p0 ? const Color(0xFF5E2230) : TbColors.border;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TbColors.surface2,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topRow(),
              const SizedBox(height: 8),
              _title(),
              const SizedBox(height: 11),
              _metaRow(),
              const SizedBox(height: 11),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topRow() => Row(
    children: [
      TbSignalDot(color: TbRepoColor.forSlug(card.repo), size: 7),
      const SizedBox(width: 7),
      Flexible(
        child: Text(card.repo, overflow: TextOverflow.ellipsis,
            style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.2)),
      ),
      const SizedBox(width: 7),
      Text('#${card.number}', style: TbText.label(size: 10, weight: FontWeight.w600, color: TbColors.dim)),
      const Spacer(),
      Text(card.isPr ? '⑃' : '◇',
          style: TextStyle(fontSize: 12, color: card.isPr ? TbColors.cyan : TbColors.dim)),
    ],
  );

  Widget _title() => Text.rich(
    TextSpan(children: [
      if (card.isDraft)
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(padding: EdgeInsets.only(right: 6), child: TbBadge('Draft', TbSignal.gray, small: true)),
        ),
      TextSpan(text: card.title),
    ]),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TbText.body(size: 13, weight: FontWeight.w600, color: TbColors.text, height: 1.4),
  );

  Widget _metaRow() => Wrap(
    spacing: 6,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (card.priority != null)
        TbBadge(CockpitPalette.priorityLabel(card.priority!), CockpitPalette.prioritySignal(card.priority!),
            small: true, tooltip: CockpitPalette.priorityTooltip(card.priority!)),
      if (card.points != null) TbBadge('${card.points} SP', TbSignal.gray, small: true),
      if (card.hasSubIssues) _subProgress(),
      if (card.isStale) TbBadge('⏱ ${card.staleDays}d', TbSignal.orange, small: true),
    ],
  );

  Widget _subProgress() {
    final pct = (card.subTotal ?? 0) == 0 ? 0.0 : (card.subDone ?? 0) / card.subTotal!;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 26, height: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct, backgroundColor: TbColors.canvas,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF54AE39)),
          ),
        ),
      ),
      const SizedBox(width: 5),
      Text('${card.subDone}/${card.subTotal}', style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.2)),
    ]);
  }

  Widget _footer() => Row(
    children: [
      if (card.isPr) ...[
        _signalLabel('CI', BoardPalette.ciDot(card.ciState ?? PrCiState.none)),
        const SizedBox(width: 11),
        _signalLabel('Rev', BoardPalette.reviewDot(card.reviewState ?? PrReviewState.none)),
      ],
      const Spacer(),
      _assignees(),
    ],
  );

  Widget _signalLabel(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.3)),
  ]);

  Widget _assignees() {
    if (card.assignees.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < card.assignees.length; i++)
        Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 0),
          child: Transform.translate(
            offset: Offset(i == 0 ? 0 : -6.0 * i, 0),
            child: TbAvatarTile(login: card.assignees[i], size: 21),
          ),
        ),
    ]);
  }
}
```

> `TbText.body`/`TbText.label` parameter names (`size`, `weight`, `color`, `height`, `tracking`) are taken from existing usage; confirm against `tb_text.dart` and adjust if a name differs.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/projects_board/presentation/widgets/board_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects_board/presentation/view/widgets/board_card.dart test/features/projects_board/presentation/widgets/board_card_test.dart
git commit -m "feat(projects-board): board card widget"
```

---

### Task 9: Board column widget

**Files:**
- Create: `lib/features/projects_board/presentation/view/widgets/board_column.dart`
- Test: `test/features/projects_board/presentation/widgets/board_column_test.dart`

**Interfaces:**
- Consumes: `BoardColumn`, `BoardCardTile` (Task 8), `BoardPalette.columnAccent`, `boardInsightsControllerProvider` (Task 7), `TbColors`, `TbText`, `TbSignalDot`.
- Produces: `class BoardColumnView extends ConsumerWidget { const BoardColumnView({required this.column, required this.onCardTap, this.width = 236}); final BoardColumn column; final void Function(BoardCard) onCardTap; final double width; }`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/presentation/widgets/board_column_test.dart
//
// Test summary:
// - Renders the column label, count, and its cards.
// - Empty column shows the "No items" placeholder.
// - When the insights controller holds a line for this status, the AI insight row renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';
import 'package:turbo_board/features/projects_board/presentation/view/widgets/board_column.dart';

const _col = BoardColumn(status: IssueStatus.inProgress, label: 'In Progress', cards: [
  BoardCard(id: 'o/r#1', type: BoardItemType.issue, owner: 'o', repo: 'r', number: 1, title: 'Card one',
      status: IssueStatus.inProgress, priority: IssuePriority.p1),
]);

Widget _host(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(overrides: overrides, child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('renders label, count, cards', (tester) async {
    await tester.pumpWidget(_host(BoardColumnView(column: _col, onCardTap: (_) {})));
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Card one'), findsOneWidget);
  });

  testWidgets('empty column shows placeholder', (tester) async {
    await tester.pumpWidget(_host(const BoardColumnView(column: BoardColumn(status: IssueStatus.done, label: 'Done'),
        onCardTap: _noop)));
    expect(find.text('No items'), findsOneWidget);
  });

  testWidgets('shows AI insight line when controller has one', (tester) async {
    await tester.pumpWidget(_host(
      BoardColumnView(column: _col, onCardTap: (_) {}),
      overrides: [
        boardInsightsControllerProvider.overrideWith(() => _StubInsights({IssueStatus.inProgress: '1 P0 blocking'})),
      ],
    ));
    expect(find.text('1 P0 blocking'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
  });
}

void _noop(BoardCard _) {}

class _StubInsights extends BoardInsightsController {
  _StubInsights(this._data);
  final Map<IssueStatus, String> _data;
  @override
  AsyncValue<Map<IssueStatus, String>>? build() => AsyncValue.data(_data);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects_board/presentation/widgets/board_column_test.dart`
Expected: FAIL — widget missing.

- [ ] **Step 3: Write the widget**

```dart
// lib/features/projects_board/presentation/view/widgets/board_column.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/board_data.dart';
import '../../helpers/board_palette.dart';
import '../../providers/projects_board_provider.dart';
import 'board_card.dart';

/// One Status column: accent header, optional AI insight line, scrollable cards.
class BoardColumnView extends ConsumerWidget {
  const BoardColumnView({super.key, required this.column, required this.onCardTap, this.width = 236});

  final BoardColumn column;
  final void Function(BoardCard) onCardTap;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(boardInsightsControllerProvider);
    final accent = BoardPalette.columnAccent(column.status);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border(top: BorderSide(color: accent, width: 2)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(accent),
          if (insights != null) _insightRow(insights),
          Expanded(child: _cards()),
        ],
      ),
    );
  }

  Widget _header(Color accent) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
    child: Row(children: [
      TbSignalDot(color: accent, size: 7),
      const SizedBox(width: 8),
      Text(column.label, style: TbText.label(size: 11, weight: FontWeight.w600, tracking: 0.4)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: TbColors.surface2,
          border: Border.all(color: TbColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('${column.count}', style: TbText.label(size: 10, weight: FontWeight.w600, color: TbColors.muted)),
      ),
    ]),
  );

  Widget _insightRow(AsyncValue<Map<IssueStatus, String>> insights) => insights.when(
    loading: () => _insightShell(const _Shimmer()),
    error: (_, _) => const SizedBox.shrink(),
    data: (map) {
      final line = map[column.status];
      if (line == null) return const SizedBox.shrink();
      return _insightShell(Text(line, style: TbText.body(size: 11, color: TbColors.muted, height: 1.4)));
    },
  );

  Widget _insightShell(Widget child) => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
    decoration: BoxDecoration(
      color: TbColors.canvas,
      border: Border.all(color: TbColors.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 2, height: 16, color: TbColors.cyan),
      const SizedBox(width: 7),
      const TbBadge('AI', TbSignal.info, small: true),
      const SizedBox(width: 7),
      Expanded(child: child),
    ]),
  );

  Widget _cards() {
    if (column.cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: TbColors.border, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text('No items', style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.5)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
      itemCount: column.cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => BoardCardTile(card: column.cards[i], onTap: () => onCardTap(column.cards[i])),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();
  @override
  Widget build(BuildContext context) => Container(
    height: 11,
    decoration: BoxDecoration(color: TbColors.surface2, borderRadius: BorderRadius.circular(2)),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/projects_board/presentation/widgets/board_column_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects_board/presentation/view/widgets/board_column.dart test/features/projects_board/presentation/widgets/board_column_test.dart
git commit -m "feat(projects-board): board column widget with AI insight row"
```

---

### Task 10: Board topbar (picker + AI CTA + refresh)

**Files:**
- Create: `lib/features/projects_board/presentation/view/widgets/board_topbar.dart`
- Test: `test/features/projects_board/presentation/widgets/board_topbar_test.dart`

**Interfaces:**
- Consumes: `ProjectBoardData`, `boardInsightsControllerProvider`, `selectedProjectProvider` + `SelectedProjectNotifier` (cockpit), `ProjectPickerList` (`lib/features/lead_cockpit/presentation/view/widgets/project_picker.dart`), `projectsBoardProvider`, `TbColors`, `TbText`.
- Produces: `class BoardTopbar extends ConsumerWidget { const BoardTopbar({required this.board}); final ProjectBoardData board; }`. Behavior: title text; project-picker button → popup menu hosting `ProjectPickerList` (on select: `selectedProjectProvider.notifier.select(p)` + `ref.invalidate(projectsBoardProvider)` + `boardInsightsControllerProvider.notifier.clear()`); "✨ AI Insights" button driving `BoardInsightsController.generate(board)` with idle/loading/data/error visuals; refresh `IconButton` invalidating `projectsBoardProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/presentation/widgets/board_topbar_test.dart
//
// Test summary:
// - Renders the board title and the AI Insights CTA when idle.
// - Tapping the CTA calls BoardInsightsController.generate (state leaves null).
// - While loading, the CTA shows a spinner.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';
import 'package:turbo_board/features/projects_board/presentation/view/widgets/board_topbar.dart';

const _board = ProjectBoardData(title: 'Mobile Q3 Roadmap');

class _RecordingInsights extends BoardInsightsController {
  static int calls = 0;
  @override
  AsyncValue<Map<IssueStatus, String>>? build() => null;
  @override
  Future<void> generate(ProjectBoardData board) async => calls++;
}

void main() {
  testWidgets('renders title and AI CTA', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: BoardTopbar(board: _board)))));
    expect(find.text('Mobile Q3 Roadmap'), findsOneWidget);
    expect(find.textContaining('AI Insights'), findsOneWidget);
  });

  testWidgets('CTA triggers generate', (tester) async {
    _RecordingInsights.calls = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [boardInsightsControllerProvider.overrideWith(_RecordingInsights.new)],
      child: MaterialApp(home: Scaffold(body: BoardTopbar(board: _board))),
    ));
    await tester.tap(find.textContaining('AI Insights'));
    await tester.pump();
    expect(_RecordingInsights.calls, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects_board/presentation/widgets/board_topbar_test.dart`
Expected: FAIL — widget missing.

- [ ] **Step 3: Write the widget**

```dart
// lib/features/projects_board/presentation/view/widgets/board_topbar.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../../lead_cockpit/presentation/view/widgets/project_picker.dart';
import '../../providers/projects_board_provider.dart';
import '../../../data/models/board_data.dart';

/// Board topbar: title, project picker, inert group/filter, AI insights CTA, refresh.
class BoardTopbar extends ConsumerWidget {
  const BoardTopbar({super.key, required this.board});

  final ProjectBoardData board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(boardInsightsControllerProvider);
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TbColors.border))),
      child: Row(children: [
        Flexible(
          child: Text(board.title, overflow: TextOverflow.ellipsis,
              style: TbText.label(size: 14, weight: FontWeight.w600, tracking: 0.5)),
        ),
        const SizedBox(width: 14),
        _pickerButton(context, ref),
        const Spacer(),
        _aiCta(context, ref, insights),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(LucideIcons.refreshCw, size: 15, color: TbColors.muted),
          onPressed: () => ref.invalidate(projectsBoardProvider),
        ),
      ]),
    );
  }

  Widget _pickerButton(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    icon: const Icon(LucideIcons.chevronDown, size: 13, color: TbColors.dim),
    label: Text('Switch board', style: TbText.label(size: 11, color: TbColors.muted, tracking: 0.3)),
    style: OutlinedButton.styleFrom(side: const BorderSide(color: TbColors.border)),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: TbColors.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ProjectPickerList(
            selectedKey: ref.read(selectedProjectProvider)?.key,
            onSelected: (p) {
              ref.read(selectedProjectProvider.notifier).select(p);
              ref.invalidate(projectsBoardProvider);
              ref.read(boardInsightsControllerProvider.notifier).clear();
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    ),
  );

  Widget _aiCta(BuildContext context, WidgetRef ref, AsyncValue<Map<IssueStatus, String>>? insights) {
    final loading = insights?.isLoading ?? false;
    final hasData = insights?.hasValue ?? false;
    final error = insights?.hasError ?? false;
    final label = error
        ? 'Retry insights'
        : hasData
        ? '↻ Regenerate'
        : '✨ AI Insights';
    return OutlinedButton(
      style: OutlinedButton.styleFrom(side: const BorderSide(color: TbColors.cyan)),
      onPressed: loading ? null : () => ref.read(boardInsightsControllerProvider.notifier).generate(board),
      child: loading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label, style: TbText.label(size: 11, weight: FontWeight.w600, color: TbColors.cyan, tracking: 0.3)),
    );
  }
}
```

> Confirm `AsyncValue` has `isLoading`/`hasValue`/`hasError` in this Riverpod version (it does in recent versions). If the project pins an older version, switch to `insights?.maybeWhen(...)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/projects_board/presentation/widgets/board_topbar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects_board/presentation/view/widgets/board_topbar.dart test/features/projects_board/presentation/widgets/board_topbar_test.dart
git commit -m "feat(projects-board): board topbar with picker + AI insights CTA"
```

---

### Task 11: Phone column selector

**Files:**
- Create: `lib/features/projects_board/presentation/view/widgets/phone_column_selector.dart`
- Test: `test/features/projects_board/presentation/widgets/phone_column_selector_test.dart`

**Interfaces:**
- Consumes: `BoardColumn`, `BoardPalette.columnAccent`, `TbColors`, `TbText`.
- Produces: `class PhoneColumnSelector extends StatelessWidget { const PhoneColumnSelector({required this.columns, required this.selectedIndex, required this.onSelect}); final List<BoardColumn> columns; final int selectedIndex; final void Function(int) onSelect; }`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/projects_board/presentation/widgets/phone_column_selector_test.dart
//
// Test summary:
// - Renders a pill per column with its label and count.
// - Tapping a pill calls onSelect with its index.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/view/widgets/phone_column_selector.dart';

const _cols = [
  BoardColumn(status: IssueStatus.triage, label: 'Triage'),
  BoardColumn(status: IssueStatus.inProgress, label: 'In Progress', cards: [
    BoardCard(id: 'o/r#1', type: BoardItemType.issue, owner: 'o', repo: 'r', number: 1, title: 'x',
        status: IssueStatus.inProgress),
  ]),
];

void main() {
  testWidgets('renders pills and reports taps', (tester) async {
    var picked = -1;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PhoneColumnSelector(
      columns: _cols, selectedIndex: 0, onSelect: (i) => picked = i,
    ))));
    expect(find.textContaining('In Progress'), findsOneWidget);
    await tester.tap(find.textContaining('In Progress'));
    expect(picked, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/projects_board/presentation/widgets/phone_column_selector_test.dart`
Expected: FAIL — widget missing.

- [ ] **Step 3: Write the widget**

```dart
// lib/features/projects_board/presentation/view/widgets/phone_column_selector.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../data/models/board_data.dart';
import '../../helpers/board_palette.dart';

/// Horizontal status pills shown on phone widths; one per column.
class PhoneColumnSelector extends StatelessWidget {
  const PhoneColumnSelector({super.key, required this.columns, required this.selectedIndex, required this.onSelect});

  final List<BoardColumn> columns;
  final int selectedIndex;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      for (var i = 0; i < columns.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        _pill(columns[i], i == selectedIndex, () => onSelect(i)),
      ],
    ]),
  );

  Widget _pill(BoardColumn col, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: active ? TbColors.navy : TbColors.surface,
        border: Border.all(color: active ? TbColors.cyan : TbColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, color: BoardPalette.columnAccent(col.status)),
        const SizedBox(width: 7),
        Text('${col.label} · ${col.count}',
            style: TbText.label(size: 11, weight: FontWeight.w600, tracking: 0.3,
                color: active ? const Color(0xFFB2EBFF) : TbColors.muted)),
      ]),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/projects_board/presentation/widgets/phone_column_selector_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/projects_board/presentation/view/widgets/phone_column_selector.dart test/features/projects_board/presentation/widgets/phone_column_selector_test.dart
git commit -m "feat(projects-board): phone column selector"
```

---

### Task 12: Board screen (states + responsive)

**Files:**
- Create: `lib/features/projects_board/presentation/view/projects_board_screen.dart`
- Test: `test/features/projects_board/presentation/view/projects_board_screen_test.dart`

**Interfaces:**
- Consumes: `selectedProjectProvider`, `projectsBoardProvider`, `ProjectPickerList`, `BoardTopbar`, `BoardColumnView`, `PhoneColumnSelector`, `boardColumnOrder`, `BoardCard`, `TbBreakpoints`, `TbColors`, GoRouter `context.push`.
- Produces: `class ProjectsBoardScreen extends HookConsumerWidget { static const routeName = 'projectsBoard'; const ProjectsBoardScreen(); }`. Card tap: PR → `context.push('/pr/${card.owner}/${card.repo}/${card.number}')`; issue → open `card.url`-equivalent on GitHub via the existing open-on-github helper or `launchUrl`. (Use the same URL-open path the cockpit's stuck rows use — read `stuck_issue_row.dart` for the helper.)

- [ ] **Step 1: Read the existing URL-open helper**

Run: `sed -n '1,60p' lib/features/lead_cockpit/presentation/view/widgets/stuck_issue_row.dart`
Note the function/util used to open a GitHub URL (e.g. `url_launcher`'s `launchUrl` or an app helper). Reuse it verbatim for issue-card taps. Build the issue URL as `https://github.com/{owner}/{repo}/issues/{number}` when no stored URL exists.

- [ ] **Step 2: Write the failing test**

```dart
// test/features/projects_board/presentation/view/projects_board_screen_test.dart
//
// Test summary:
// - With no project selected, shows the project picker empty-state.
// - With a selected project and a mock board, renders the topbar title and columns.
// - Error from the board provider shows the message + Retry.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import 'package:turbo_board/features/projects_board/data/repositories/projects_board_repository.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';
import 'package:turbo_board/features/projects_board/presentation/view/projects_board_screen.dart';

class _SelStub extends SelectedProjectNotifier {
  _SelStub(this._p);
  final ProjectRef? _p;
  @override
  ProjectRef? build() => _p;
}

Widget _app({required List<Override> overrides}) =>
    ProviderScope(overrides: overrides, child: const MaterialApp(home: ProjectsBoardScreen()));

void main() {
  testWidgets('no project -> picker empty state', (tester) async {
    await tester.pumpWidget(_app(overrides: [
      selectedProjectProvider.overrideWith(() => _SelStub(null)),
    ]));
    await tester.pump();
    expect(find.textContaining('project', findRichText: true), findsWidgets);
  });

  testWidgets('selected project -> renders board', (tester) async {
    await tester.pumpWidget(_app(overrides: [
      selectedProjectProvider.overrideWith(() => _SelStub(const ProjectRef(owner: 'o', number: 4, title: 'B'))),
      projectsBoardRepositoryProvider.overrideWithValue(const MockProjectsBoardRepository()),
    ]));
    await tester.pump(const Duration(milliseconds: 400)); // mock latency
    await tester.pumpAndSettle();
    expect(find.text('Mobile Q3 Roadmap'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Write the screen**

```dart
// lib/features/projects_board/presentation/view/projects_board_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/theme/tb_breakpoints.dart';
import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../lead_cockpit/presentation/view/widgets/project_picker.dart';
import '../../data/models/board_data.dart';
import '../providers/projects_board_provider.dart';
import 'widgets/board_column.dart';
import 'widgets/board_topbar.dart';
import 'widgets/phone_column_selector.dart';

class ProjectsBoardScreen extends HookConsumerWidget {
  const ProjectsBoardScreen({super.key});

  static const String routeName = 'projectsBoard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProjectProvider);
    if (selected == null) return _PickerEmptyState();

    final board = ref.watch(projectsBoardProvider);
    return board.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _ErrorState(message: '$err', onRetry: () => ref.invalidate(projectsBoardProvider)),
      data: (data) => _BoardBody(board: data),
    );
  }
}

class _BoardBody extends HookWidget {
  const _BoardBody({required this.board});
  final ProjectBoardData board;

  @override
  Widget build(BuildContext context) {
    final phoneIndex = useState(_defaultIndex(board));
    return Column(children: [
      BoardTopbar(board: board),
      Expanded(
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < TbBreakpoints.mobile) {
            final i = phoneIndex.value.clamp(0, board.columns.length - 1);
            return Column(children: [
              PhoneColumnSelector(columns: board.columns, selectedIndex: i, onSelect: (n) => phoneIndex.value = n),
              Expanded(child: BoardColumnView(column: board.columns[i], width: double.infinity,
                  onCardTap: (c) => _openCard(context, c))),
            ]);
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(22),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < board.columns.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                SizedBox(
                  height: constraints.maxHeight - 44,
                  child: BoardColumnView(
                    column: board.columns[i],
                    width: board.columns[i].status == IssueStatus.inProgress ? 272 : 236,
                    onCardTap: (c) => _openCard(context, c),
                  ),
                ),
              ],
            ]),
          );
        }),
      ),
    ]);
  }

  static int _defaultIndex(ProjectBoardData b) {
    final i = b.columns.indexWhere((c) => c.status == IssueStatus.inProgress);
    return i < 0 ? 0 : i;
  }

  void _openCard(BuildContext context, BoardCard card) {
    if (card.isPr && card.owner != null) {
      context.push('/pr/${card.owner}/${card.repo}/${card.number}');
    } else {
      // Issue detail is a separate feature; open on GitHub for now.
      _openOnGithub(card);
    }
  }
}
```

Add, at the bottom of the file, the `_PickerEmptyState`, `_ErrorState`, and `_openOnGithub` helpers. Mirror the cockpit empty-state/error visuals and the cockpit's URL-open util discovered in Step 1:

```dart
class _PickerEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Pick a project board', style: TbText.label(size: 14, weight: FontWeight.w600, tracking: 0.5)),
        const SizedBox(height: 6),
        Text('Choose a GitHub ProjectV2 board to view as a kanban board.',
            textAlign: TextAlign.center, style: TbText.body(size: 13, color: TbColors.muted)),
        const SizedBox(height: 16),
        ProjectPickerList(onSelected: (p) => _selectFrom(context, p)),
      ]),
    ),
  );
}
```

> `ProjectPickerList.onSelected` needs to persist the choice. Make `_PickerEmptyState` a `ConsumerWidget` (not plain `StatelessWidget`) so it can call `ref.read(selectedProjectProvider.notifier).select(p)`. Adjust the class accordingly when writing.

`_openOnGithub(BoardCard card)` builds the URL (`https://github.com/{owner}/{repo}/{issues|pull}/{number}`) and opens it with the same util the cockpit uses (from Step 1).

- [ ] **Step 4: Generate (no new codegen, but run analyzer)**

Run: `dart analyze lib/features/projects_board`
Expected: no errors. Fix any (e.g. make `_PickerEmptyState` a `ConsumerWidget`).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/projects_board/presentation/view/projects_board_screen_test.dart`
Expected: PASS. Adjust the picker empty-state finder text to match the copy you wrote.

- [ ] **Step 6: Commit**

```bash
git add lib/features/projects_board/presentation/view/projects_board_screen.dart test/features/projects_board/presentation/view/projects_board_screen_test.dart
git commit -m "feat(projects-board): board screen with states + responsive layout"
```

---

### Task 13: Route + nav entries

**Files:**
- Modify: `lib/shared/router/app_router.dart` (import + GoRoute) then `dart run build_runner build -d`
- Modify: `lib/shared/ui/shell/nav_rail.dart` (nav item)
- Modify: `lib/shared/ui/shell/bottom_nav.dart` (tab)
- Test: `test/shared/router/projects_board_route_test.dart`

**Interfaces:**
- Consumes: `ProjectsBoardScreen` + `routeName` (Task 12).
- Produces: route `/projects` registered inside the ShellRoute; rail + bottom-nav entries pointing at `/projects`.

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/router/projects_board_route_test.dart
//
// Test summary:
// - The app router resolves '/projects' to ProjectsBoardScreen.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/projects_board/presentation/view/projects_board_screen.dart';
import 'package:turbo_board/shared/router/app_router.dart';

void main() {
  test('router has a /projects route named projectsBoard', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final router = c.read(appRouterProvider);
    final match = router.configuration.findMatch('/projects');
    expect(match.routes.whereType<GoRoute>().any((r) => r.name == ProjectsBoardScreen.routeName), isTrue);
  });
}
```

> If `findMatch`/`configuration` differ in this go_router version, fall back to asserting the route exists by navigating: build the router, call `router.go('/projects')`, and check `router.routerDelegate.currentConfiguration.last.matchedLocation == '/projects'`. Pick whichever compiles.

- [ ] **Step 2: Add the route**

In `app_router.dart`, add the import and a `GoRoute` inside the ShellRoute `routes:` list (after `/lead-cockpit`):

```dart
import '../../features/projects_board/presentation/view/projects_board_screen.dart';
```

```dart
          GoRoute(
            path: '/projects',
            name: ProjectsBoardScreen.routeName,
            builder: (context, state) => _opaque(const ProjectsBoardScreen()),
          ),
```

Run: `dart run build_runner build -d` (router uses codegen for the provider).

- [ ] **Step 3: Add the nav-rail entry**

In `nav_rail.dart`, add after the Lead Cockpit `_NavItem`:

```dart
                  _NavItem(
                    icon: LucideIcons.kanban,
                    label: 'Projects board',
                    collapsed: collapsed,
                    active: location == '/projects',
                    onTap: () => context.go('/projects'),
                  ),
```

> Confirm `LucideIcons.kanban` exists in the installed `lucide_icons_flutter`; if not, use `LucideIcons.columns3` or `LucideIcons.trello`.

- [ ] **Step 4: Add the bottom-nav tab**

In `bottom_nav.dart`, add to `_tabs`:

```dart
    (LucideIcons.kanban, 'Projects', '/projects'),
```

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/shared/router/projects_board_route_test.dart && dart analyze lib/shared`
Expected: PASS + no analyzer errors.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/router/app_router.dart lib/shared/ui/shell/nav_rail.dart lib/shared/ui/shell/bottom_nav.dart test/shared/router/projects_board_route_test.dart
git commit -m "feat(projects-board): register /projects route + nav entries"
```

---

### Task 14: Pre-completion gate

**Files:** none (verification only).

- [ ] **Step 1: Regenerate everything clean**

Run: `dart run build_runner build -d`
Expected: success, no conflicts.

- [ ] **Step 2: Format**

Run: `dart format --line-length 120 .`
Then: `dart format --line-length 120 --set-exit-if-changed .`
Expected: second run reports 0 changed files.

- [ ] **Step 3: Analyze**

Run: `dart analyze`
Expected: "No issues found!" (fix any warnings/errors in the new feature before proceeding).

- [ ] **Step 4: Full test suite**

Run: `flutter test`
Expected: all green (new projects_board tests + untouched existing suites).

- [ ] **Step 5: Manual smoke (two targets)**

Run: `flutter run -d macos` then `flutter run -d chrome`
Verify: nav to Projects board; pick a project; columns render; tap a PR card → detail overlay; tap "✨ AI Insights" → lines populate (or a clear no-key error); resize to phone width → pills + single column.

- [ ] **Step 6: Commit any fixes**

```bash
git add -A
git commit -m "chore(projects-board): format, analyze, test pass"
```

---

## Self-Review

**Spec coverage:**
- New feature + `/projects` route + nav → Tasks 12, 13. ✓
- Live data reusing cockpit query/pagination/picker/SelectedProjectNotifier → Tasks 2, 4, 7. ✓
- PR content (CI/review/draft) additive query + mapper → Tasks 2, 3. ✓
- Models / mapper / repo / mock sample → Tasks 1, 3, 4. ✓
- On-demand AI insights via CTA (not auto), grounded in ColumnFacts → Tasks 1 (facts), 3 (compute), 5 (prompt/parser/repo), 7 (controller), 9 (render), 10 (CTA). ✓
- Read-only; PR→detail overlay, issue→GitHub → Task 12. ✓
- Responsive desktop/tablet/phone + states (loading/empty/per-column-empty/error) → Tasks 9, 12. ✓
- Palette accents + PR dots → Task 6. ✓
- Tests for mapper / provider / card / screen / facts / insights → Tasks 1,3,4,5,6,7,8,9,10,11,12,13. ✓
- Pre-completion gate (format/analyze/test) → Task 14. ✓

**Placeholder scan:** No TBD/TODO; every code step has full code. Three explicit "confirm against existing API" notes (Result accessor, TbText param names, AsyncValue getters, go_router match API, Lucide icon) are guardrails, not placeholders — each names the fallback.

**Type consistency:** `boardFromProjectItems`, `ProjectsBoardRepository.fetchBoard`, `boardInsights`, `BoardInsightsController.generate/clear`, `BoardCardTile`, `BoardColumnView`, `BoardTopbar`, `PhoneColumnSelector`, `ProjectsBoardScreen.routeName` are used identically across producer/consumer blocks. `ColumnFacts` fields (p0Unowned/missingEstimate/stuckCount/ciRedNumbers) consistent between Task 1, 3, 5. ✓
```
