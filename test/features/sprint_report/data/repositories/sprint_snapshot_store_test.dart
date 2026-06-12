// Test summary:
// - capture records a point per day; a same-day re-capture overwrites it (idempotent).
// - history returns points ascending by day.
// - buildBurndownActuals produces a contiguous day-0..today line, carrying gaps forward,
//   and defaults day 0 to the committed total when no snapshot exists for it.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_snapshot.dart';
import 'package:turbo_board/features/sprint_report/data/repositories/sprint_snapshot_store.dart';

final _now = DateTime(2026, 6, 12);

void main() {
  group('InMemorySprintSnapshotStore', () {
    test('captures one point per day and overwrites a same-day re-capture', () async {
      final store = InMemorySprintSnapshotStore();
      await store.capture(sprintKey: 'k', day: 0, remaining: 168, now: _now);
      await store.capture(sprintKey: 'k', day: 1, remaining: 150, now: _now);
      await store.capture(sprintKey: 'k', day: 1, remaining: 142, now: _now); // overwrite day 1

      final history = await store.history('k');
      expect(history.map((s) => s.day), [0, 1]);
      expect(history.last.remaining, 142);
    });

    test('isolates sprints by key', () async {
      final store = InMemorySprintSnapshotStore();
      await store.capture(sprintKey: 'a', day: 0, remaining: 100, now: _now);
      await store.capture(sprintKey: 'b', day: 0, remaining: 50, now: _now);

      expect((await store.history('a')).single.remaining, 100);
      expect((await store.history('b')).single.remaining, 50);
    });
  });

  group('buildBurndownActuals', () {
    test('fills a contiguous line and carries gaps forward', () {
      final history = [
        const SprintSnapshot(day: 1, remaining: 150, date: '2026-06-09'),
        const SprintSnapshot(day: 3, remaining: 120, date: '2026-06-11'),
      ];
      final actual = buildBurndownActuals(committedPoints: 168, todayDay: 4, history: history);

      // day0 → committed default, day1 → 150, day2 → carry 150, day3 → 120, day4 → carry 120
      expect(actual, [168, 150, 150, 120, 120]);
    });

    test('day 0 defaults to committed when no snapshot exists yet', () {
      final actual = buildBurndownActuals(committedPoints: 80, todayDay: 0, history: const []);
      expect(actual, [80]);
    });
  });
}
