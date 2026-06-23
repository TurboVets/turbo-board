// Test summary:
// - SprintFlow enumerates the iteration window as weekdays only (no Sat/Sun tiles).
// - `opened` is bucketed by createdAt, `done` by closedAt, onto the matching day.
// - Tickets carry the `#number`, title, repo and url for the day-detail popup.
// - Stamps landing on a weekend are dropped (no tile to hold them).
// - Activity outside the sprint window is excluded.
// - With no iteration dates, the window falls back to earliest activity → today.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/lead_cockpit/data/repositories/cockpit_mapper.dart';

// Sprint: Mon 2026-06-15 + 14d → weekdays 15,16,17,18,19,22,23,24,25,26.
const _sprintStart = '2026-06-15';
final _now = DateTime(2026, 6, 23);

Map<String, dynamic> _item({
  required int number,
  required String title,
  String repo = 'mobile',
  String? createdAt,
  String? closedAt,
  bool withSprint = true,
}) {
  return {
    'updatedAt': '2026-06-20T00:00:00',
    'content': {
      '__typename': 'Issue',
      'number': number,
      'title': title,
      'url': 'https://github.com/x/$number',
      'createdAt': ?createdAt,
      'closedAt': ?closedAt,
      'repository': {'name': repo},
      'assignees': {'nodes': <dynamic>[]},
    },
    'fieldValues': {
      'nodes': [
        {
          '__typename': 'ProjectV2ItemFieldSingleSelectValue',
          'name': 'In Progress',
          'field': {'name': 'Status'},
        },
        if (withSprint)
          {
            '__typename': 'ProjectV2ItemFieldIterationValue',
            'title': 'Sprint 24',
            'startDate': _sprintStart,
            'duration': 14,
            'field': {'name': 'Sprint'},
          },
      ],
    },
  };
}

SprintFlow _flowOf(List<Map<String, dynamic>> nodes) => cockpitFromProjectItems('Board', nodes, now: _now).flow;

FlowDay _dayOn(SprintFlow flow, int day) => flow.days.firstWhere((d) => d.date.day == day);

void main() {
  group('SprintFlow', () {
    test('enumerates the iteration window as weekdays only', () {
      final flow = _flowOf([
        _item(
          number: 1,
          title: 'a',
          createdAt:
              '$_sprintStart'
              'T10:00:00',
        ),
      ]);

      expect(flow.days.map((d) => d.date.day), [15, 16, 17, 18, 19, 22, 23, 24, 25, 26]);
      expect(flow.days.every((d) => d.date.weekday <= DateTime.friday), isTrue);
    });

    test('buckets opened by createdAt and done by closedAt onto the right day', () {
      final flow = _flowOf([
        _item(number: 1, title: 'opened wed', createdAt: '2026-06-17T09:00:00'),
        _item(number: 2, title: 'done thu', closedAt: '2026-06-18T16:00:00'),
        _item(number: 3, title: 'opened+done', createdAt: '2026-06-16T08:00:00', closedAt: '2026-06-19T12:00:00'),
      ]);

      expect(_dayOn(flow, 17).opened, 1);
      expect(_dayOn(flow, 18).done, 1);
      expect(_dayOn(flow, 16).opened, 1);
      expect(_dayOn(flow, 19).done, 1);
    });

    test('carries ticket number, title, repo and url for the popup', () {
      final flow = _flowOf([
        _item(number: 412, title: 'Fix deeplink', repo: 'mobile', closedAt: '2026-06-16T10:00:00'),
      ]);

      final ticket = _dayOn(flow, 16).doneTickets.single;
      expect(ticket.number, '#412');
      expect(ticket.title, 'Fix deeplink');
      expect(ticket.repo, 'mobile');
      expect(ticket.url, 'https://github.com/x/412');
    });

    test('drops stamps that land on a weekend', () {
      // 2026-06-20 is a Saturday — inside the window but not a weekday tile.
      final flow = _flowOf([_item(number: 1, title: 'sat close', closedAt: '2026-06-20T10:00:00')]);

      expect(flow.days.any((d) => d.date.day == 20), isFalse);
      expect(flow.days.fold<int>(0, (s, d) => s + d.done), 0);
    });

    test('excludes activity outside the sprint window', () {
      final flow = _flowOf([
        _item(number: 1, title: 'before', createdAt: '2026-06-01T10:00:00'),
        _item(number: 2, title: 'after', closedAt: '2026-07-10T10:00:00'),
      ]);

      expect(flow.days.fold<int>(0, (s, d) => s + d.opened + d.done), 0);
    });

    test('falls back to earliest-activity→today window without iteration dates', () {
      final flow = _flowOf([_item(number: 1, title: 'no sprint', createdAt: '2026-06-16T10:00:00', withSprint: false)]);

      expect(flow.days, isNotEmpty);
      expect(_dayOn(flow, 16).opened, 1);
      // Today (Tue 2026-06-23) is included as the last weekday.
      expect(flow.days.last.date.day, 23);
    });
  });
}
