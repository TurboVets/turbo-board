import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders GitHub markdown. Isolates the gpt_markdown dependency to one file.
///
/// Task-list items (`- [x]` / `- [ ]`) are pulled out and rendered with a
/// font-sized [Icon] instead of gpt_markdown's stock Material Checkbox (which
/// carries a ~48px tap target) or a unicode ballot box (which falls back to an
/// oversized symbol/emoji glyph on real devices). Everything else goes through
/// gpt_markdown unchanged.
class MarkdownBody extends StatelessWidget {
  const MarkdownBody(this.markdown, {super.key});

  final String markdown;

  /// A single GitHub task-list line: indent, `[ ]`/`[x]`, then the label.
  static final _taskLine = RegExp(r'^([ \t]*)[-*] \[([ xX])\] (.*)$');

  void _openLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (markdown.trim().isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    // Match the app's predominant 13px body text — bodySmall is 14px, which reads
    // a touch larger than the surrounding UI (most noticeable on list rows).
    final body = text.bodySmall?.copyWith(fontSize: 13);

    // gpt_markdown sizes headings from its own oversized Typography by default
    // (h3 ~24px), which dwarfs the body text. Scale headings off the app text
    // theme so they read like GitHub markdown: modestly larger + bold.
    final headings = GptMarkdownThemeData(
      brightness: Theme.of(context).brightness,
      h1: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      h2: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      h3: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      h4: body?.copyWith(fontWeight: FontWeight.w700),
      h5: body?.copyWith(fontWeight: FontWeight.w700),
      h6: body?.copyWith(fontWeight: FontWeight.w600),
    );

    final markerColor = body?.color ?? Theme.of(context).colorScheme.onSurface;
    final bodyFs = body?.fontSize ?? 13;
    const listFs = 12.0; // list item text, a touch smaller than body
    final markerStyle = body?.copyWith(color: markerColor, fontSize: listFs);

    // gpt_markdown bakes config.style into the list label's spans before this
    // builder runs, so a DefaultTextStyle can't resize the label (span styles
    // win). A textScaler is the one lever that scales already-built text — use it
    // to pin list labels to [listFs] regardless of the device's ambient scaling.
    Widget listRow(Widget marker, Widget child) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(right: 8), child: marker),
          Expanded(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(listFs / bodyFs)),
              child: child,
            ),
          ),
        ],
      ),
    );

    Widget md(String source) => GptMarkdownTheme(
      gptThemeData: headings,
      child: GptMarkdown(
        source,
        style: body,
        onLinkTap: (url, _) => _openLink(url),
        unOrderedListBuilder: (context, child, config) => listRow(
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: markerColor, shape: BoxShape.circle),
            ),
          ),
          child,
        ),

        codeBuilder: (context, code, language, closed) => Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(4),
          ),

          padding: const EdgeInsets.all(8),
          child: Text(
            language,
            style: body?.copyWith(fontFamily: 'monospace', fontSize: (10)),
          ),
        ),

        orderedListBuilder: (context, no, child, config) => listRow(Text('$no.', style: markerStyle), child),
      ),
    );

    // Split the source into ordered segments: runs of plain markdown (rendered
    // by gpt_markdown) interleaved with task-list rows (rendered by us).
    final children = <Widget>[];
    final buffer = <String>[];
    void flush() {
      if (buffer.isEmpty) return;
      final source = buffer.join('\n').trim();
      if (source.isNotEmpty) children.add(md(source));
      buffer.clear();
    }

    for (final line in markdown.split('\n')) {
      final m = _taskLine.firstMatch(line);
      if (m == null) {
        buffer.add(line);
        continue;
      }
      flush();
      final indent = m.group(1)!.replaceAll('\t', '  ').length;
      final checked = m.group(2)!.toLowerCase() == 'x';
      children.add(_TaskRow(checked: checked, label: m.group(3)!, indent: indent, body: body, content: md));
    }
    flush();

    if (children.length == 1) return children.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// A single task-list row: a font-sized checkbox icon beside the (markdown) label.
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.checked,
    required this.label,
    required this.indent,
    required this.body,
    required this.content,
  });

  final bool checked;
  final String label;
  final int indent;
  final TextStyle? body;
  final Widget Function(String) content;

  @override
  Widget build(BuildContext context) {
    final size = (body?.fontSize ?? 13) + 2;
    final color = body?.color ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.only(left: indent * 8.0, top: 1, bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 6),
            child: Icon(checked ? Icons.check_box_outlined : Icons.check_box_outline_blank, size: size, color: color),
          ),
          Expanded(child: content(label)),
        ],
      ),
    );
  }
}
