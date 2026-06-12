// Test summary:
// - enumerates sprints oldest→newest and selects the current one by date
// - rolls up committed/done points and status slices (Triage/Cancelled excluded)
// - counts estimated vs unestimated tickets
// - builds epic rollups from subIssuesSummary (B2)
// - groups points per assignee (done / in-progress / remaining)
// - honours an explicit selectedSprint
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';
import 'package:turbo_board/features/sprint_report/data/repositories/sprint_report_mapper.dart';

Map<String, dynamic> _node({
  required String status,
  num? complexity,
  required String sprint,
  required String start,
  int duration = 14,
  String repo = 'mobile',
  List<String> assignees = const ['alice'],
  String title = 'Issue',
  int subsTotal = 0,
  int subsDone = 0,
  double subsPercent = 0,
}) => {
  'updatedAt': '2026-06-10T00:00:00Z',
  'content': {
    '__typename': 'Issue',
    'title': title,
    'repository': {'name': repo},
    'assignees': {
      'nodes': [
        for (final a in assignees) {'login': a},
      ],
    },
    if (subsTotal > 0) 'subIssuesSummary': {'total': subsTotal, 'completed': subsDone, 'percentCompleted': subsPercent},
  },
  'fieldValues': {
    'nodes': [
      {
        '__typename': 'ProjectV2ItemFieldSingleSelectValue',
        'name': status,
        'field': {'name': 'Status'},
      },
      if (complexity != null)
        {
          '__typename': 'ProjectV2ItemFieldNumberValue',
          'number': complexity,
          'field': {'name': 'Complexity'},
        },
      {
        '__typename': 'ProjectV2ItemFieldIterationValue',
        'title': sprint,
        'startDate': start,
        'duration': duration,
        'field': {'name': 'Sprint'},
      },
    ],
  },
};

void main() {
  final now = DateTime(2026, 6, 11); // inside Sprint A (Jun 3 + 14d)
  const a = 'Sprint A';
  const b = 'Sprint B';
  const startA = '2026-06-03';
  const startB = '2026-05-20';

  final nodes = [
    _node(status: 'Done', complexity: 5, sprint: a, start: startA),
    _node(status: 'Done', complexity: 3, sprint: a, start: startA),
    _node(status: 'In Progress', complexity: 8, sprint: a, start: startA),
    _node(status: 'In Review', complexity: 2, sprint: a, start: startA),
    _node(status: 'Not Started', sprint: a, start: startA), // unestimated
    _node(
      status: 'Not Started',
      complexity: 10,
      sprint: a,
      start: startA,
      title: 'Epic X',
      subsTotal: 4,
      subsDone: 2,
      subsPercent: 50,
    ),
    _node(status: 'Cancelled', complexity: 99, sprint: a, start: startA), // excluded from slices
    _node(status: 'Done', complexity: 7, sprint: b, start: startB), // older sprint
  ];

  test('enumerates sprints and selects the current one', () {
    final r = sprintReportFromProjectItems('Mobile Space', nodes, now: now);
    expect(r.sprintTitles, [b, a]); // oldest → newest
    expect(r.sprintIndex, 1); // Sprint A is current
    expect(r.hasPrev, isTrue);
    expect(r.hasNext, isFalse);
    expect(r.sprintName, '$a · Mobile Space');
  });

  test('rolls up points and status slices (Cancelled excluded)', () {
    final r = sprintReportFromProjectItems('Mobile Space', nodes, now: now);
    // done 5+3=8, inProgress 8, inReview 2, notStarted 0+10=10 → committed 28
    expect(r.pointsCommitted, 28);
    expect(r.pointsDone, 8);
    expect(r.status.firstWhere((s) => s.kind == ReportStatusKind.done).tickets, 2);
    expect(r.status.firstWhere((s) => s.kind == ReportStatusKind.notStarted).points, 10);
  });

  test('estimate coverage', () {
    final r = sprintReportFromProjectItems('Mobile Space', nodes, now: now);
    expect(r.totalTickets, 7); // Sprint A items incl. Cancelled
    expect(r.unestimatedTickets, 1);
    expect(r.estimatedTickets, 6);
  });

  test('epic rollup from subIssuesSummary', () {
    final r = sprintReportFromProjectItems('Mobile Space', nodes, now: now);
    expect(r.epics, hasLength(1));
    final e = r.epics.single;
    expect(e.title, 'Epic X');
    expect(e.subsDone, 2);
    expect(e.subsTotal, 4);
    expect(e.percent, 50);
    expect(e.pointsTotal, 10);
    expect(e.pointsDone, 5); // 10 * 50%
  });

  test('points per assignee', () {
    final r = sprintReportFromProjectItems('Mobile Space', nodes, now: now);
    final alice = r.people.firstWhere((p) => p.handle == 'alice');
    expect(alice.done, 8);
    expect(alice.inProgress, 8);
    expect(alice.remaining, 12); // in-review 2 + not-started 10
  });

  test('explicit selectedSprint picks the older sprint', () {
    final r = sprintReportFromProjectItems('Mobile Space', nodes, now: now, selectedSprint: b);
    expect(r.sprintIndex, 0);
    expect(r.pointsCommitted, 7);
    expect(r.totalTickets, 1);
  });
}
