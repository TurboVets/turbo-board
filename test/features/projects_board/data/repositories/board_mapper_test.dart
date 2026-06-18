// Test summary:
// - Parses an Issue item into a BoardCard with priority/points/sub-progress.
// - Parses a PullRequest item: CI rollup -> PrCiState, reviewDecision -> PrReviewState, isDraft.
// - Groups items into the five ordered columns; unknown/null status -> Not Started.
// - Drops cancelled items entirely.
// - Flags staleDays once past stuckAfterDays.
// - Computes ColumnFacts: p0Unowned, missingEstimate, stuckCount, ciRedNumbers.
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
    final b = boardFromProjectItems('B', [
      issueNode(number: 5, title: 'P0 unowned', priority: 'P0'), // p0Unowned, missingEstimate
      prNode(number: 6, title: 'Red CI', ci: 'FAILURE', priority: 'P1'), // ciRed, missingEstimate
    ], now: now);
    final facts = columnFor(b, IssueStatus.inProgress).facts;
    expect(facts.p0Unowned, 1);
    expect(facts.missingEstimate, 2);
    expect(facts.ciRedNumbers, [6]);
  });
}
