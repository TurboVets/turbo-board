// Test summary:
// - SprintReport.percentDone and unestimatedPercent round correctly
// - EpicProgress.percent computes from sub-issues
// - AssigneePoints total/open sum the segments
// - Burndown.pointsLeft is the last actual snapshot (or committed when empty)
// - the mock repository returns the seeded sample
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';
import 'package:turbo_board/features/sprint_report/data/repositories/sprint_report_repository.dart';
import 'package:turbo_core/core.dart';

void main() {
  test('AssigneePoints total / open', () {
    const p = AssigneePoints(handle: 'x', done: 12, inProgress: 16, remaining: 10);
    expect(p.total, 38);
    expect(p.open, 26);
  });

  test('EpicProgress percent', () {
    const e = EpicProgress(title: 'e', subsDone: 8, subsTotal: 12, pointsDone: 34, pointsTotal: 52);
    expect(e.percent, 67);
  });

  group('Burndown.pointsLeft', () {
    test('last snapshot when present', () {
      const b = Burndown(
        committedPoints: 168,
        totalDays: 14,
        todayDay: 8,
        snapshotsCaptured: 2,
        snapshotsTotal: 14,
        actualRemaining: [168, 120, 94],
      );
      expect(b.pointsLeft, 94);
    });
    test('committed when no snapshots', () {
      const b = Burndown(committedPoints: 168, totalDays: 14, todayDay: 0, snapshotsCaptured: 0, snapshotsTotal: 14);
      expect(b.pointsLeft, 168);
    });
  });

  test('mock repository returns the seeded sample with consistent rollups', () async {
    final result = await const MockSprintReportRepository().fetchReport();
    final r = (result as ResultSuccess<SprintReport>).data;
    expect(r.percentDone, 44); // 74 / 168
    expect(r.unestimatedPercent, 8); // 12 / 145
    expect(r.status.fold<int>(0, (s, e) => s + e.points), r.pointsCommitted); // slices sum to committed
    expect(r.burndown.pointsLeft, 94);
  });
}
