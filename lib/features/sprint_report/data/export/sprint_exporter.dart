import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

/// Wraps the only impure export side-effects so widgets and pure builders stay
/// testable. Substitute a fake in tests / mock mode.
abstract interface class SprintExporter {
  Future<void> copySummary(String text);

  /// Opens the OS mail composer via `mailto:`. Returns false if no handler.
  Future<bool> openEmail({required String subject, required String body});

  /// Routes the PDF to the native print/save dialog (desktop), share sheet
  /// (mobile), or browser print (web).
  Future<void> sharePdf(pw.Document doc, {required String filename});
}

class DefaultSprintExporter implements SprintExporter {
  const DefaultSprintExporter();

  @override
  Future<void> copySummary(String text) => Clipboard.setData(ClipboardData(text: text));

  @override
  Future<bool> openEmail({required String subject, required String body}) async {
    final uri = Uri(
      scheme: 'mailto',
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri);
  }

  @override
  Future<void> sharePdf(pw.Document doc, {required String filename}) =>
      Printing.layoutPdf(onLayout: (_) => doc.save(), name: filename);
}
