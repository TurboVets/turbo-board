// Test summary:
// - a fake SprintExporter records calls (proves the interface shape compiles/usable)
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:turbo_board/features/sprint_report/data/export/sprint_exporter.dart';

class _Fake implements SprintExporter {
  String? copied;
  ({String subject, String body})? emailed;
  String? pdfName;
  @override
  Future<void> copySummary(String text) async => copied = text;
  @override
  Future<bool> openEmail({required String subject, required String body}) async {
    emailed = (subject: subject, body: body);
    return true;
  }

  @override
  Future<void> sharePdf(pw.Document doc, {required String filename}) async => pdfName = filename;
}

void main() {
  test('fake exporter records calls', () async {
    final f = _Fake();
    await f.copySummary('hi');
    await f.openEmail(subject: 's', body: 'b');
    await f.sharePdf(pw.Document(), filename: 'r.pdf');
    expect(f.copied, 'hi');
    expect(f.emailed!.subject, 's');
    expect(f.pdfName, 'r.pdf');
  });
}
