// test/features/sprint_report/data/export/sprint_pdf_builder_test.dart
// Test summary:
// - full report builds a non-empty PDF (document.save() returns bytes)
// - digest builds a non-empty PDF
// - builds without throwing when narrative lists and metrics are empty
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/export/report_metrics.dart';
import 'package:turbo_board/features/sprint_report/data/export/sprint_export_format.dart';
import 'package:turbo_board/features/sprint_report/data/export/sprint_pdf_builder.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_narrative_report.dart';

const _report = SprintNarrativeReport(
  executiveSummary: 'Closed 82 of 120 points.',
  keyWins: ['Released Checkout v2'],
  overallStatus: SprintOutlook.behind,
  deliverables: [
    Deliverable(title: 'Checkout v2', status: 'Complete', description: 'Dashboard', impact: 'Self-service'),
  ],
  outcome: 'Solid sprint.',
);
const _metrics = [MetricRow(label: 'Points delivered', previous: '71', current: '82', delta: '↑ 15%')];

void main() {
  test('full report builds non-empty PDF', () async {
    final doc = buildSprintPdf(
      sprintName: 'Sprint 24',
      dateRange: 'Jun 10 - Jun 24',
      reportDate: 'Jun 24, 2026',
      report: _report,
      metrics: _metrics,
      format: SprintExportFormat.fullReport,
    );
    final bytes = await doc.save();
    expect(bytes.lengthInBytes, greaterThan(0));
  });

  test('digest builds non-empty PDF', () async {
    final doc = buildSprintPdf(
      sprintName: 'Sprint 24',
      dateRange: 'r',
      reportDate: 'd',
      report: _report,
      metrics: _metrics,
      format: SprintExportFormat.digest,
    );
    expect((await doc.save()).lengthInBytes, greaterThan(0));
  });

  test('empty narrative builds without throwing', () async {
    final doc = buildSprintPdf(
      sprintName: 'S',
      dateRange: 'r',
      reportDate: 'd',
      report: const SprintNarrativeReport(executiveSummary: 'x'),
      metrics: const [],
      format: SprintExportFormat.fullReport,
    );
    expect((await doc.save()).lengthInBytes, greaterThan(0));
  });
}
