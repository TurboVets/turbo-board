// lib/features/sprint_report/data/export/sprint_pdf_builder.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/sprint_narrative_report.dart';
import 'report_metrics.dart';
import 'sprint_export_format.dart';

/// Maps non-Latin-1 typographic glyphs to ASCII so the pdf package's
/// built-in WinAnsi fonts render them instead of missing-glyph boxes.
String sanitizePdfText(String s) => s
    .replaceAll('•', '-')
    .replaceAll('↑', '+')
    .replaceAll('↓', '-')
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('‘', "'")
    .replaceAll('’', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('…', '...');

// Light, print-friendly palette (the on-screen app is dark; printed docs are not).
const _ink = PdfColor.fromInt(0xFF1A1A1F);
const _muted = PdfColor.fromInt(0xFF8A8A94);
const _rule = PdfColor.fromInt(0xFFE6E6EA);
const _accent = PdfColor.fromInt(0xFF0E9FBD);

String _statusLabel(SprintOutlook h) => switch (h) {
  SprintOutlook.onTrack => 'On Track',
  SprintOutlook.atRisk => 'At Risk',
  SprintOutlook.behind => 'Behind Schedule',
};

pw.Widget _h(String text) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 16, bottom: 6),
  padding: const pw.EdgeInsets.only(bottom: 4),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _rule)),
  ),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink),
  ),
);

pw.Widget _bullets(List<String> items) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: items
      .map(
        (i) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text('- ${sanitizePdfText(i)}', style: const pw.TextStyle(fontSize: 10, color: _ink)),
        ),
      )
      .toList(),
);

pw.Widget? _section(String title, List<String> items) => items.isEmpty
    ? null
    : pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_h(title), _bullets(items)]);

/// Builds the narrative Sprint Report PDF on a light theme. `format` controls
/// whether every section renders (full) or only summary + status + deliverables
/// + metrics (digest).
pw.Document buildSprintPdf({
  required String sprintName,
  required String dateRange,
  required String reportDate,
  required SprintNarrativeReport report,
  required List<MetricRow> metrics,
  required SprintExportFormat format,
}) {
  final doc = pw.Document();
  final isFull = format == SprintExportFormat.fullReport;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
      build: (context) {
        final blocks = <pw.Widget>[
          // Header
          pw.Text(
            'Sprint Report - ${sanitizePdfText(sprintName)}',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${sanitizePdfText(dateRange)}  ·  Report date: ${sanitizePdfText(reportDate)}',
            style: const pw.TextStyle(fontSize: 10, color: _muted),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Status: ${_statusLabel(report.overallStatus)}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _accent),
          ),
          // Executive summary
          _h('Executive Summary'),
          pw.Text(sanitizePdfText(report.executiveSummary), style: const pw.TextStyle(fontSize: 10, color: _ink)),
        ];

        if (report.keyWins.isNotEmpty) blocks.add(_section('Key Wins', report.keyWins)!);

        if (report.deliverables.isNotEmpty) {
          blocks.add(_h('Major Deliverables'));
          blocks.add(
            pw.TableHelper.fromTextArray(
              cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted),
              headerDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _rule)),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              border: null,
              headers: const ['Initiative', 'Status', 'Description', 'Impact'],
              data: report.deliverables
                  .map(
                    (d) => [
                      sanitizePdfText(d.title),
                      sanitizePdfText(d.status),
                      sanitizePdfText(d.description),
                      sanitizePdfText(d.impact),
                    ],
                  )
                  .toList(),
            ),
          );
        }

        if (metrics.isNotEmpty) {
          blocks.add(_h('Metrics'));
          blocks.add(
            pw.TableHelper.fromTextArray(
              cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted),
              headerDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _rule)),
              ),
              border: null,
              headers: const ['Metric', 'Previous', 'Current', 'Change'],
              data: metrics
                  .map(
                    (m) => [
                      sanitizePdfText(m.label),
                      m.previous != null ? sanitizePdfText(m.previous!) : '-',
                      sanitizePdfText(m.current),
                      m.delta != null ? sanitizePdfText(m.delta!) : '-',
                    ],
                  )
                  .toList(),
            ),
          );
        }

        if (isFull) {
          blocks.add(_section('Platform Highlights', report.techHighlights.platform) ?? pw.SizedBox());
          blocks.add(_section('Product Highlights', report.techHighlights.product) ?? pw.SizedBox());
          blocks.add(_section('Challenges & Risks', report.challenges) ?? pw.SizedBox());
          blocks.add(_section('Mitigations', report.mitigations) ?? pw.SizedBox());
          blocks.add(_section('Learnings', report.learnings) ?? pw.SizedBox());
          blocks.add(_section('Next Sprint Priorities', report.nextPriorities) ?? pw.SizedBox());
          blocks.add(_section('Team Recognition', report.recognition) ?? pw.SizedBox());
        }

        if (report.outcome.isNotEmpty) {
          blocks.add(_h('Sprint Outcome'));
          blocks.add(
            pw.Text(
              sanitizePdfText(report.outcome),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink),
            ),
          );
        }

        return blocks;
      },
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'TurboBoard · page ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ),
    ),
  );
  return doc;
}
