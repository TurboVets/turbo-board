// test/features/sprint_report/data/export/report_metrics_test.dart
// Test summary:
// - current-only report produces rows with null previous/delta
// - with a previous sprint, points/tickets rows carry a delta
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/export/report_metrics.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';

SprintReport _r({required int done, required int tickets}) => SprintReport(
  sprintName: 'S',
  dateRange: 'r',
  daysRemaining: 2,
  totalTickets: tickets,
  pointsCommitted: 120,
  repoCount: 3,
  forecastLabel: 'f',
  forecastDetail: 'd',
  behind: true,
  pointsDone: done,
  estimatedTickets: tickets,
  estimatedPoints: 110,
  unestimatedTickets: 6,
  burndown: const Burndown(committedPoints: 120, totalDays: 10, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 10),
);

void main() {
  test('current-only rows have no delta', () {
    final rows = computeReportMetrics(_r(done: 82, tickets: 47));
    expect(rows, isNotEmpty);
    expect(rows.every((m) => m.previous == null && m.delta == null), isTrue);
    expect(rows.any((m) => m.label.toLowerCase().contains('points') && m.current == '82'), isTrue);
  });

  test('previous sprint yields deltas', () {
    final rows = computeReportMetrics(_r(done: 82, tickets: 47), previous: _r(done: 71, tickets: 38));
    final points = rows.firstWhere((m) => m.label.toLowerCase().contains('points'));
    expect(points.previous, '71');
    expect(points.delta, isNotNull);
  });
}
