import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders GitHub markdown. Isolates the gpt_markdown dependency to one file.
class MarkdownBody extends StatelessWidget {
  const MarkdownBody(this.markdown, {super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    if (markdown.trim().isEmpty) return const SizedBox.shrink();
    return GptMarkdown(
      markdown,
      style: Theme.of(context).textTheme.bodyMedium,
      onLinkTap: (url, _) {
        final uri = Uri.tryParse(url);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }
}
