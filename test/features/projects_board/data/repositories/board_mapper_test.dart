// Test summary:
// - Parses an Issue item into a BoardCard with priority/points/sub-progress.
// - Parses a PullRequest item: CI rollup -> PrCiState, reviewDecision -> PrReviewState, isDraft.
// - Groups items into the five ordered columns; unknown/null status -> Not Started.
// - Drops cancelled items entirely.
// - Flags staleDays once past stuckAfterDays.
// - Computes ColumnFacts: p0Unowned, missingEstimate, stuckCount, ciRedNumbers.
// - Parses the Sprint iteration value onto each card.
// - Builds the sprint catalog oldest->newest and flags the current iteration.
// - boardForSprint filters columns to one iteration and recomputes facts; null = unchanged.
// - sprintTitleForTab resolves current/previous/next/all against the catalog.
// - The iteration field config drives the catalog so empty future sprints appear.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/lead_cockpit/data/repositories/cockpit_mapper.dart' show stuckAfterDays;
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
  String? sprintTitle,
  String? sprintStart,
  int sprintDuration = 14,
}) => {
  'updatedAt': updatedAt,
  'content': {
    '__typename': 'Issue',
    'number': number,
    'title': title,
    'url': 'https://github.com/o/r/issues/$number',
    'repository': {
      'name': 'r',
      'owner': {'login': 'o'},
    },
    'assignees': {
      'nodes': [
        for (final a in assignees) {'login': a},
      ],
    },
    'subIssuesSummary': sub == null ? null : {'total': sub[1], 'completed': sub[0]},
  },
  'fieldValues': {
    'nodes': [
      {
        '__typename': 'ProjectV2ItemFieldSingleSelectValue',
        'name': status,
        'field': {'name': 'Status'},
      },
      if (priority != null)
        {
          '__typename': 'ProjectV2ItemFieldSingleSelectValue',
          'name': priority,
          'field': {'name': 'Priority'},
        },
      if (complexity != null)
        {
          '__typename': 'ProjectV2ItemFieldNumberValue',
          'number': complexity,
          'field': {'name': 'Complexity'},
        },
      if (sprintTitle != null)
        {
          '__typename': 'ProjectV2ItemFieldIterationValue',
          'title': sprintTitle,
          'startDate': sprintStart,
          'duration': sprintDuration,
          'field': {'name': 'Sprint'},
        },
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
    'repository': {
      'name': 'r',
      'owner': {'login': 'o'},
    },
    'assignees': {'nodes': []},
    'commits': {
      'nodes': [
        {
          'commit': {
            'statusCheckRollup': ci == null ? null : {'state': ci},
          },
        },
      ],
    },
  },
  'fieldValues': {
    'nodes': [
      {
        '__typename': 'ProjectV2ItemFieldSingleSelectValue',
        'name': status,
        'field': {'name': 'Status'},
      },
      if (priority != null)
        {
          '__typename': 'ProjectV2ItemFieldSingleSelectValue',
          'name': priority,
          'field': {'name': 'Priority'},
        },
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
    final b = boardFromProjectItems('B', [issueNode(number: 4, title: 'Old', updatedAt: old)], now: now);
    expect(columnFor(b, IssueStatus.inProgress).cards.single.staleDays, stuckAfterDays + 2);
  });

  test('computes column facts', () {
    final old = now.subtract(Duration(days: stuckAfterDays + 1)).toIso8601String();
    final b = boardFromProjectItems('B', [
      issueNode(number: 5, title: 'P0 unowned', priority: 'P0'), // p0Unowned, missingEstimate
      prNode(number: 6, title: 'Red CI', ci: 'FAILURE', priority: 'P1'), // ciRed, missingEstimate
      issueNode(number: 7, title: 'Stale item', updatedAt: old), // stuckCount
    ], now: now);
    final facts = columnFor(b, IssueStatus.inProgress).facts;
    expect(facts.p0Unowned, 1);
    expect(facts.missingEstimate, 3);
    expect(facts.ciRedNumbers, [6]);
    expect(facts.stuckCount, 1);
  });

  // ── Sprint (iteration) handling ───────────────────────────────────────────

  // Three back-to-back 14-day sprints; sprintNow (Jun 10) sits inside Sprint 24
  // (Jun 3 → Jun 17). Sprint 23: May 20 → Jun 3. Sprint 25: Jun 17 → Jul 1.
  final sprintNow = DateTime.parse('2026-06-10T00:00:00Z');
  Map<String, dynamic> sprintIssue(int n, String sprint, String start) =>
      issueNode(number: n, title: 'I$n', sprintTitle: sprint, sprintStart: start);
  List<Map<String, dynamic>> threeSprintNodes() => [
    sprintIssue(1, 'Sprint 23', '2026-05-20T00:00:00Z'),
    sprintIssue(2, 'Sprint 24', '2026-06-03T00:00:00Z'),
    sprintIssue(3, 'Sprint 24', '2026-06-03T00:00:00Z'),
    sprintIssue(4, 'Sprint 25', '2026-06-17T00:00:00Z'),
  ];

  test('parses the sprint iteration value onto each card', () {
    final b = boardFromProjectItems('B', [
      issueNode(number: 1, title: 'In sprint', sprintTitle: 'Sprint 24', sprintStart: '2026-06-03T00:00:00Z'),
    ], now: sprintNow);
    expect(columnFor(b, IssueStatus.inProgress).cards.single.sprint, 'Sprint 24');
  });

  test('builds sprint catalog oldest->newest and flags the current iteration', () {
    final b = boardFromProjectItems('B', threeSprintNodes(), now: sprintNow);
    expect(b.sprints.map((s) => s.title).toList(), ['Sprint 23', 'Sprint 24', 'Sprint 25']);
    expect(b.sprints.where((s) => s.isCurrent).map((s) => s.title).toList(), ['Sprint 24']);
    expect(b.sprints.firstWhere((s) => s.title == 'Sprint 24').end, DateTime.parse('2026-06-17T00:00:00Z'));
  });

  test('boardForSprint filters to one iteration and recomputes counts', () {
    final b = boardFromProjectItems('B', threeSprintNodes(), now: sprintNow);
    final filtered = boardForSprint(b, 'Sprint 24');
    expect(columnFor(filtered, IssueStatus.inProgress).cards.map((c) => c.number).toList(), [2, 3]);
    // null title (All Tasks) returns the board unchanged.
    expect(boardForSprint(b, null), same(b));
  });

  test('sprintTitleForTab resolves current/previous/next/all', () {
    final s = boardFromProjectItems('B', threeSprintNodes(), now: sprintNow).sprints;
    expect(sprintTitleForTab(s, SprintTab.current), 'Sprint 24');
    expect(sprintTitleForTab(s, SprintTab.previous), 'Sprint 23');
    expect(sprintTitleForTab(s, SprintTab.next), 'Sprint 25');
    expect(sprintTitleForTab(s, SprintTab.all), isNull);
    // No catalog at all -> every tab resolves to null (no filtering).
    expect(sprintTitleForTab(const [], SprintTab.current), isNull);
  });

  test('iteration config drives the catalog, including an empty future sprint', () {
    // Only Sprint 24 has an item; the field config still lists 23/24/25, so the
    // "next" sprint (25, no items) must appear and resolve.
    final b = boardFromProjectItems(
      'B',
      [sprintIssue(1, 'Sprint 24', '2026-06-03T00:00:00Z')],
      now: sprintNow,
      iterations: [
        {'title': 'Sprint 23', 'startDate': '2026-05-20', 'duration': 14},
        {'title': 'Sprint 24', 'startDate': '2026-06-03', 'duration': 14},
        {'title': 'Sprint 25', 'startDate': '2026-06-17', 'duration': 14},
      ],
    );
    expect(b.sprints.map((s) => s.title).toList(), ['Sprint 23', 'Sprint 24', 'Sprint 25']);
    expect(sprintTitleForTab(b.sprints, SprintTab.next), 'Sprint 25');
  });
}
