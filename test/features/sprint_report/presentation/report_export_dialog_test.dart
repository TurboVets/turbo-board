// test/features/sprint_report/presentation/report_export_dialog_test.dart
// Test summary:
// - with a generated narrative, tapping "Copy summary" calls exporter.copySummary with the built text
// - tapping "PDF" calls exporter.sharePdf
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';
import 'package:turbo_board/features/sprint_report/data/export/sprint_exporter.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_narrative_report.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';
import 'package:turbo_board/features/sprint_report/presentation/providers/sprint_export_provider.dart';
import 'package:turbo_board/features/sprint_report/presentation/view/widgets/report_export_dialog.dart';

class _Fake implements SprintExporter {
  String? copied;
  bool pdfCalled = false;
  @override
  Future<void> copySummary(String text) async => copied = text;
  @override
  Future<bool> openEmail({required String subject, required String body}) async => true;
  @override
  Future<void> sharePdf(pw.Document doc, {required String filename}) async => pdfCalled = true;
}

SprintReport _report() => const SprintReport(
  sprintName: 'Sprint 24',
  dateRange: 'Jun 10 - Jun 24',
  daysRemaining: 2,
  totalTickets: 47,
  pointsCommitted: 120,
  repoCount: 3,
  forecastLabel: 'behind',
  forecastDetail: 'd',
  behind: true,
  pointsDone: 82,
  estimatedTickets: 41,
  estimatedPoints: 110,
  unestimatedTickets: 6,
  burndown: Burndown(committedPoints: 120, totalDays: 10, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 10),
);

void main() {
  testWidgets('Copy summary invokes exporter with built text', (tester) async {
    final fake = _Fake();
    final report = _report();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sprintExporterProvider.overrideWithValue(fake),
          // Seed a generated narrative so the dialog shows the preview + actions.
          sprintNarrativeControllerProvider.overrideWith(() => _SeededController()),
        ],
        child: MaterialApp(
          home: Scaffold(body: ReportExportDialog(report: report)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy summary'));
    await tester.pumpAndSettle();
    expect(fake.copied, isNotNull);
    expect(fake.copied, contains('Sprint 24'));
  });

  testWidgets('PDF invokes exporter.sharePdf', (tester) async {
    final fake = _Fake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sprintExporterProvider.overrideWithValue(fake),
          sprintNarrativeControllerProvider.overrideWith(() => _SeededController()),
        ],
        child: MaterialApp(
          home: Scaffold(body: ReportExportDialog(report: _report())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(fake.pdfCalled, isTrue);
  });
}

class _SeededController extends SprintNarrativeController {
  @override
  AsyncValue<SprintNarrativeReport>? build() => const AsyncValue.data(
    SprintNarrativeReport(executiveSummary: 'Closed 82/120.', keyWins: ['Shipped X'], outcome: 'Good.'),
  );
}
