import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/sprint_report.dart';

part 'report_metrics.freezed.dart';

/// One row in the report's Metrics table. `previous`/`delta` are null when no
/// prior sprint is available (current-only). Custom (user-typed) rows reuse this.
@freezed
sealed class MetricRow with _$MetricRow {
  const factory MetricRow({required String label, String? previous, required String current, String? delta}) =
      _MetricRow;
}

String _deltaPct(int prev, int curr) {
  if (prev == 0) return curr == 0 ? '0%' : '+$curr';
  final pct = ((curr - prev) / prev * 100).round();
  return '${pct >= 0 ? '↑' : '↓'} ${pct.abs()}%';
}

/// REAL metrics computed deterministically from the board. Never fabricated.
List<MetricRow> computeReportMetrics(SprintReport current, {SprintReport? previous}) {
  return [
    MetricRow(
      label: 'Points delivered',
      previous: previous?.pointsDone.toString(),
      current: current.pointsDone.toString(),
      delta: previous == null ? null : _deltaPct(previous.pointsDone, current.pointsDone),
    ),
    MetricRow(
      label: 'Tickets',
      previous: previous?.totalTickets.toString(),
      current: current.totalTickets.toString(),
      delta: previous == null ? null : _deltaPct(previous.totalTickets, current.totalTickets),
    ),
    MetricRow(
      label: 'Completion',
      previous: previous == null ? null : '${previous.percentDone}%',
      current: '${current.percentDone}%',
      delta: previous == null ? null : _deltaPct(previous.percentDone, current.percentDone),
    ),
    MetricRow(
      label: 'Unestimated tickets',
      previous: previous?.unestimatedTickets.toString(),
      current: current.unestimatedTickets.toString(),
      delta: previous == null ? null : _deltaPct(previous.unestimatedTickets, current.unestimatedTickets),
    ),
  ];
}
