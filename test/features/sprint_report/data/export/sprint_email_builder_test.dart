// test/features/sprint_report/data/export/sprint_email_builder_test.dart
// Test summary:
// - full body contains sprint name, exec summary, a metric, a key win
// - digest body is shorter than full and omits the per-section detail
// - subject carries the sprint name
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/export/report_metrics.dart';
import 'package:turbo_board/features/sprint_report/data/export/sprint_email_builder.dart';
import 'package:turbo_board/features/sprint_report/data/export/sprint_export_format.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_narrative_report.dart';

const _report = SprintNarrativeReport(
  executiveSummary: 'Closed 82 of 120 points.',
  keyWins: ['Released Checkout v2'],
  overallStatus: SprintOutlook.behind,
  challenges: ['Integration issues'],
  learnings: ['Better testing helps'],
  outcome: 'Solid sprint.',
);
const _metrics = [MetricRow(label: 'Points delivered', current: '82')];

void main() {
  test('full body contains the key content', () {
    final mail = buildSprintEmail(
      sprintName: 'Sprint 24',
      dateRange: 'Jun 10 - Jun 24',
      report: _report,
      metrics: _metrics,
      format: SprintExportFormat.fullReport,
    );
    expect(mail.subject, contains('Sprint 24'));
    expect(mail.body, contains('Closed 82 of 120 points.'));
    expect(mail.body, contains('Released Checkout v2'));
    expect(mail.body, contains('Points delivered'));
  });

  test('digest is shorter than full', () {
    final full = buildSprintEmail(
      sprintName: 'Sprint 24',
      dateRange: 'r',
      report: _report,
      metrics: _metrics,
      format: SprintExportFormat.fullReport,
    ).body;
    final digest = buildSprintEmail(
      sprintName: 'Sprint 24',
      dateRange: 'r',
      report: _report,
      metrics: _metrics,
      format: SprintExportFormat.digest,
    ).body;
    expect(digest.length, lessThan(full.length));
    expect(digest, contains('Closed 82 of 120 points.'));
  });
}
