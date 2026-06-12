// Test summary:
// - cockpitFromProjectItems picks the current sprint and counts statuses within it.
// - Per-assignee load buckets open items; busiest member reaches loadPercent 100.
// - Stuck list includes items aged past the threshold, P0/old items flagged critical and sorted first.
// - At-risk counts open P0/P1 that are aging; unestimated counts open items lacking complexity.
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

    test('buckets load by assignee with the busiest at 100%', () {
      final data = cockpitFromProjectItems('B', [
        _item(title: '1', assignees: ['ann'], ageDays: 1),
        _item(title: '2', assignees: ['ann'], status: 'In Review', ageDays: 1),
        _item(title: '3', assignees: ['bob'], ageDays: 1),
      ], now: _now);

      final ann = data.team.firstWhere((m) => m.handle == 'ann');
      final bob = data.team.firstWhere((m) => m.handle == 'bob');
      expect(ann.loadPercent, 100);
      expect(ann.wip, 1);
      expect(ann.inReview, 1);
      expect(bob.loadPercent, 50);
      expect(data.team.first.handle, 'ann'); // sorted by load desc
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

    test('ignores non-Issue content', () {
      final data = cockpitFromProjectItems('B', [
        _item(title: 'draft', typename: 'DraftIssue', ageDays: 1),
        _item(title: 'real', ageDays: 1),
      ], now: _now);

      expect(data.sprint.totalIssues, 1);
    });
  });
}
