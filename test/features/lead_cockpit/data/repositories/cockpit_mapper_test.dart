// Test summary:
// - cockpitFromProjectItems picks the current sprint and counts statuses within it.
// - Per-assignee load sums story points, counts WIP/review/done/stuck/unsized/high-priority; sorted by points desc.
// - Member items carry per-item age (when stuck), sub-issue rollup, and the GitHub url.
// - Stuck list includes items aged past the threshold, P0/old items flagged critical and sorted first.
// - At-risk counts open P0/P1 that are aging; unestimated counts open items lacking complexity.
// - Epics (issues with sub-issues) are excluded from points and unestimated counts.
// - Non-Issue content and items outside the current sprint are excluded.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/repositories/cockpit_mapper.dart';

final _now = DateTime(2026, 6, 11);

Map<String, dynamic> _item({
  required String title,
  String repo = 'mobile',
  List<String> assignees = const [],
  String status = 'In Progress',
  String? priority,
  num? complexity,
  int? subTotal,
  int? subDone,
  String sprint = 'Sprint 24',
  String sprintStart = '2026-06-08',
  int sprintDuration = 14,
  required int ageDays,
  String typename = 'Issue',
}) {
  final updated = _now.subtract(Duration(days: ageDays)).toIso8601String();
  return {
    'updatedAt': updated,
    'content': {
      '__typename': typename,
      'number': 1,
      'title': title,
      'url': 'https://x',
      'repository': {'name': repo},
      'assignees': {
        'nodes': [
          for (final a in assignees) {'login': a},
        ],
      },
      if (subTotal != null) 'subIssuesSummary': {'total': subTotal, 'completed': subDone ?? 0},
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
        {
          '__typename': 'ProjectV2ItemFieldIterationValue',
          'title': sprint,
          'startDate': sprintStart,
          'duration': sprintDuration,
          'field': {'name': 'Sprint'},
        },
      ],
    },
  };
}

void main() {
  group('cockpitFromProjectItems', () {
    test('counts statuses within the current sprint and names it', () {
      final data = cockpitFromProjectItems('Mobile Space', [
        _item(title: 'A', status: 'Done', ageDays: 1),
        _item(title: 'B', status: 'In Progress', ageDays: 1),
        _item(title: 'C', status: 'In Review', ageDays: 1),
        _item(title: 'Old', status: 'In Progress', sprint: 'Sprint 23', sprintStart: '2026-05-01', ageDays: 1),
      ], now: _now);

      expect(data.sprint.name, 'Sprint 24 · Mobile Space');
      expect(data.sprint.done, 1);
      expect(data.sprint.inProgress, 1);
      expect(data.sprint.inReview, 1);
      expect(data.sprint.totalIssues, 3); // Sprint 23 item excluded
      expect(data.sprint.endLabel, 'ends Jun 22');
    });

    test('buckets load by assignee, summing points, with the heaviest first', () {
      final data = cockpitFromProjectItems('B', [
        _item(title: '1', assignees: ['ann'], complexity: 5, ageDays: 1),
        _item(title: '2', assignees: ['ann'], status: 'In Review', complexity: 3, ageDays: 1),
        _item(title: '3', assignees: ['bob'], complexity: 2, ageDays: 1),
        _item(title: 'no-est', assignees: ['bob'], status: 'Not Started', ageDays: 1), // unestimated
      ], now: _now);

      final ann = data.team.firstWhere((m) => m.handle == 'ann');
      final bob = data.team.firstWhere((m) => m.handle == 'bob');
      expect(ann.points, 8); // 5 + 3
      expect(ann.wip, 1);
      expect(ann.inReview, 1);
      expect(bob.points, 2);
      expect(bob.unestimated, 1);
      expect(data.team.first.handle, 'ann'); // sorted by points desc
    });

    test('counts done-this-sprint, stuck, and high-priority per assignee', () {
      final data = cockpitFromProjectItems('B', [
        _item(title: 'shipped', assignees: ['ann'], status: 'Done', ageDays: 2),
        _item(title: 'rotting', assignees: ['ann'], priority: 'P0', complexity: 3, ageDays: 9),
        _item(title: 'fresh', assignees: ['ann'], priority: 'P2', complexity: 1, ageDays: 1),
      ], now: _now);

      final ann = data.team.firstWhere((m) => m.handle == 'ann');
      expect(ann.done, 1); // the Done item — counted but not part of open load
      expect(ann.stuck, 1); // rotting, aged past threshold
      expect(ann.highPriority, 1); // the P0
      expect(ann.points, 4); // only open items: 3 + 1
    });

    test('member items carry url, per-item age (when stuck) and sub-issue rollup', () {
      final data = cockpitFromProjectItems('B', [
        _item(title: 'rotting', assignees: ['ann'], ageDays: 9, subTotal: 8, subDone: 5),
        _item(title: 'fresh', assignees: ['ann'], status: 'Not Started', ageDays: 1),
      ], now: _now);

      final ann = data.team.firstWhere((m) => m.handle == 'ann');
      final rotting = ann.items.firstWhere((i) => i.title == 'rotting');
      final fresh = ann.items.firstWhere((i) => i.title == 'fresh');
      expect(rotting.url, 'https://x');
      expect(rotting.stuck, isTrue);
      expect(rotting.ageDays, 9);
      expect(rotting.subTotal, 8);
      expect(rotting.subDone, 5);
      expect(rotting.hasSubIssues, isTrue);
      expect(fresh.stuck, isFalse);
      expect(fresh.ageDays, 0); // age only surfaced when stuck
    });

    test('flags critical stuck items and sorts them first', () {
      final data = cockpitFromProjectItems('B', [
        _item(title: 'fresh', ageDays: 1),
        _item(title: 'aging-p2', priority: 'P2', ageDays: 5),
        _item(title: 'critical-p0', priority: 'P0', ageDays: 9),
      ], now: _now);

      final titles = data.stuck.map((s) => s.title).toList();
      expect(titles, contains('aging-p2'));
      expect(titles, contains('critical-p0'));
      expect(titles, isNot(contains('fresh'))); // under the stuck threshold
      expect(data.stuck.first.title, 'critical-p0');
      expect(data.stuck.first.critical, isTrue);
    });

    test('computes at-risk and unestimated', () {
      final data = cockpitFromProjectItems('B', [
        _item(title: 'risk', priority: 'P1', complexity: 3, ageDays: 6), // open high-pri + aging
        _item(title: 'estimated', priority: 'P2', complexity: 2, ageDays: 1),
        _item(title: 'no-estimate', priority: 'P2', ageDays: 1),
      ], now: _now);

      expect(data.sprint.atRisk, 1);
      expect(data.sprint.unestimated, 1);
    });

    test('excludes epics from points and unestimated counts', () {
      final data = cockpitFromProjectItems('B', [
        _item(title: 'epic-no-est', assignees: ['ann'], status: 'Not Started', subTotal: 4, subDone: 1, ageDays: 1),
        _item(title: 'epic-with-est', assignees: ['ann'], complexity: 13, subTotal: 3, subDone: 0, ageDays: 1),
        _item(title: 'ticket', assignees: ['ann'], complexity: 5, ageDays: 1),
        _item(title: 'no-est', assignees: ['ann'], status: 'Not Started', ageDays: 1),
      ], now: _now);

      final ann = data.team.firstWhere((m) => m.handle == 'ann');
      expect(ann.points, 5); // only the real ticket — both epics excluded
      expect(ann.unestimated, 1); // only 'no-est'; the epic without an estimate is not counted
      expect(data.sprint.unestimated, 1); // sprint-level also excludes the epic
    });

    test('maps common Status/Priority naming variants (case- and alias-tolerant)', () {
      final data = cockpitFromProjectItems('B', [
        _item(title: 'a', status: 'Backlog', ageDays: 1),
        _item(title: 'b', status: 'doing', ageDays: 1),
        _item(title: 'c', status: 'Code Review', ageDays: 1),
        _item(title: 'd', status: 'Closed', ageDays: 1),
        _item(title: 'risk', status: 'Doing', priority: 'High', complexity: 2, ageDays: 6),
      ], now: _now);

      expect(data.sprint.notStarted, 1); // Backlog
      expect(data.sprint.inProgress, 2); // doing + Doing
      expect(data.sprint.inReview, 1); // Code Review
      expect(data.sprint.done, 1); // Closed
      expect(data.sprint.atRisk, 1); // High priority, aging
    });

    test('ignores non-Issue content', () {
      final data = cockpitFromProjectItems('B', [
        _item(title: 'draft', typename: 'DraftIssue', ageDays: 1),
        _item(title: 'real', ageDays: 1),
      ], now: _now);

      expect(data.sprint.totalIssues, 1);
    });
  });
}
