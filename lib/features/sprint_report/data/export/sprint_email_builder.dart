import '../models/sprint_narrative_report.dart';
import 'report_metrics.dart';
import 'sprint_export_format.dart';

String _statusLabel(SprintOutlook h) => switch (h) {
  SprintOutlook.onTrack => '🟢 On Track',
  SprintOutlook.atRisk => '🟡 At Risk',
  SprintOutlook.behind => '🔴 Behind Schedule',
};

void _section(StringBuffer b, String title, List<String> items) {
  if (items.isEmpty) return;
  b.writeln();
  b.writeln(title.toUpperCase());
  for (final i in items) {
    b.writeln('  - $i');
  }
}

/// Builds the plain-text email subject + body (also used for clipboard copy).
({String subject, String body}) buildSprintEmail({
  required String sprintName,
  required String dateRange,
  required SprintNarrativeReport report,
  required List<MetricRow> metrics,
  required SprintExportFormat format,
}) {
  final subject = 'Sprint Report — $sprintName';
  final b = StringBuffer()
    ..writeln('Sprint Report — $sprintName')
    ..writeln(dateRange)
    ..writeln()
    ..writeln('STATUS: ${_statusLabel(report.overallStatus)}')
    ..writeln()
    ..writeln(report.executiveSummary);

  _section(b, 'Key Wins', report.keyWins);

  if (metrics.isNotEmpty) {
    b.writeln();
    b.writeln('METRICS');
    for (final m in metrics) {
      final prev = m.previous == null ? '' : ' (prev ${m.previous})';
      final delta = m.delta == null ? '' : ' ${m.delta}';
      b.writeln('  - ${m.label}: ${m.current}$prev$delta');
    }
  }

  if (format == SprintExportFormat.fullReport) {
    _section(b, 'Major Deliverables', report.deliverables.map((d) => '${d.title} — ${d.status}: ${d.impact}').toList());
    _section(b, 'Platform Highlights', report.techHighlights.platform);
    _section(b, 'Product Highlights', report.techHighlights.product);
    _section(b, 'Challenges & Risks', report.challenges);
    _section(b, 'Mitigations', report.mitigations);
    _section(b, 'Learnings', report.learnings);
    _section(b, 'Next Sprint Priorities', report.nextPriorities);
    _section(b, 'Team Recognition', report.recognition);
  }

  if (report.outcome.isNotEmpty) {
    b.writeln();
    b.writeln('OUTCOME: ${report.outcome}');
  }
  b.writeln();
  b.writeln('— TurboBoard');
  return (subject: subject, body: b.toString());
}
