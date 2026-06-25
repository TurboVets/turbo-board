import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../ai/presentation/providers/ai_provider.dart';
import '../../../data/export/report_metrics.dart';
import '../../../data/export/sprint_email_builder.dart';
import '../../../data/export/sprint_export_format.dart';
import '../../../data/export/sprint_pdf_builder.dart';
import '../../../data/models/sprint_narrative_report.dart';
import '../../../data/models/sprint_report.dart';
import '../../providers/sprint_export_provider.dart';

/// Which preview the dialog shows: the plain-text summary (for copy/email) or
/// the rendered PDF (with the printing toolbar: print / download / share).
enum _ExportView { text, pdf }

/// On-demand narrative report + export surface. Generates via the BYOK AI CTA
/// (never auto), previews the result, and exports as copy / email / PDF.
class ReportExportDialog extends HookConsumerWidget {
  const ReportExportDialog({super.key, required this.report});

  final SprintReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrative = ref.watch(sprintNarrativeControllerProvider);
    final format = useState(SprintExportFormat.fullReport);
    final view = useState(_ExportView.text);
    final customRows = useState<List<MetricRow>>(const []);

    // Not requested yet → show the generate step.
    if (narrative == null) {
      return _GenerateStep(onGenerate: () => ref.read(sprintNarrativeControllerProvider.notifier).generate(report));
    }
    // Errored → show generate step with error message.
    if (narrative is AsyncError<SprintNarrativeReport>) {
      return _GenerateStep(
        error: narrative.error.toString(),
        onGenerate: () => ref.read(sprintNarrativeControllerProvider.notifier).generate(report),
      );
    }
    if (narrative is AsyncLoading) {
      return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    }

    final data = narrative.value!;
    final metrics = [...computeReportMetrics(report), ...customRows.value];

    Future<void> run(Future<void> Function() action) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }

    final exporter = ref.read(sprintExporterProvider);

    ({String subject, String body}) mail() => buildSprintEmail(
      sprintName: report.sprintName,
      dateRange: report.dateRange,
      report: data,
      metrics: metrics,
      format: format.value,
    );

    pdfDoc() => buildSprintPdf(
      sprintName: report.sprintName,
      dateRange: report.dateRange,
      reportDate: report.dateRange,
      report: data,
      metrics: metrics,
      format: format.value,
    );

    final pdfFileName = 'sprint-report-${report.sprintName}.pdf';

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sprint Report', style: TbText.display(size: 14, tracking: 1.5)),
            const SizedBox(height: 12),
            // Length + preview-mode toggles.
            Row(
              children: [
                for (final f in SprintExportFormat.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f == SprintExportFormat.fullReport ? 'Full' : 'Digest'),
                      selected: format.value == f,
                      onSelected: (_) => format.value = f,
                    ),
                  ),
                const Spacer(),
                for (final v in _ExportView.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(v == _ExportView.text ? 'Text' : 'PDF'),
                      selected: view.value == v,
                      onSelected: (_) => view.value = v,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: view.value == _ExportView.text
                  ? SingleChildScrollView(
                      child: SelectionArea(child: Text(mail().body, style: TbText.body(size: 12))),
                    )
                  : PdfPreview(
                      // Re-render whenever the length or custom rows change.
                      key: ValueKey('${format.value}-${customRows.value.length}'),
                      build: (_) => pdfDoc().save(),
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      pdfFileName: pdfFileName,
                      useActions: true,
                    ),
            ),
            const SizedBox(height: 8),
            _AddMetricRow(onAdd: (row) => customRows.value = [...customRows.value, row]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => run(() => exporter.copySummary(mail().body)),
                  child: const Text('Copy summary'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    final m = mail();
                    run(() async {
                      final ok = await exporter.openEmail(subject: m.subject, body: m.body);
                      if (!ok) {
                        await exporter.copySummary(m.body);
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('No mail client — summary copied to clipboard')));
                        }
                      }
                    });
                  },
                  child: const Text('Email'),
                ),
                if (view.value == _ExportView.text) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => run(() => exporter.sharePdf(pdfDoc(), filename: pdfFileName)),
                    child: const Text('PDF'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateStep extends StatelessWidget {
  const _GenerateStep({required this.onGenerate, this.error});

  final VoidCallback onGenerate;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Generate Sprint Report', style: TbText.display(size: 14, tracking: 1.5)),
          const SizedBox(height: 8),
          Text(
            error ?? 'Writes an executive summary from the sprint board using your BYOK AI key.',
            textAlign: TextAlign.center,
            style: TbText.body(size: 12, color: error != null ? TbSignal.bad.border : TbColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onGenerate, child: Text(error != null ? 'Retry' : 'Generate')),
        ],
      ),
    );
  }
}

/// Minimal in-memory custom metric entry (label / previous / current).
class _AddMetricRow extends HookWidget {
  const _AddMetricRow({required this.onAdd});

  final void Function(MetricRow) onAdd;

  @override
  Widget build(BuildContext context) {
    final label = useTextEditingController();
    final prev = useTextEditingController();
    final curr = useTextEditingController();
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: label,
            decoration: const InputDecoration(hintText: 'Metric'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: prev,
            decoration: const InputDecoration(hintText: 'Prev'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: curr,
            decoration: const InputDecoration(hintText: 'Now'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          onPressed: () {
            if (label.text.trim().isEmpty || curr.text.trim().isEmpty) return;
            onAdd(
              MetricRow(
                label: label.text.trim(),
                previous: prev.text.trim().isEmpty ? null : prev.text.trim(),
                current: curr.text.trim(),
              ),
            );
            label.clear();
            prev.clear();
            curr.clear();
          },
        ),
      ],
    );
  }
}
