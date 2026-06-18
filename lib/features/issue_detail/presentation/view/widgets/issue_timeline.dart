// lib/features/issue_detail/presentation/view/widgets/issue_timeline.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../pr_detail/presentation/view/widgets/markdown_body.dart';
import '../../../data/models/issue_detail.dart';

/// Activity timeline for an issue: comment cards and compact lifecycle events.
class IssueTimeline extends StatelessWidget {
  const IssueTimeline({super.key, required this.events});

  final List<IssueTimelineEvent> events;

  String _eventText(IssueTimelineEvent e) => switch (e.kind) {
    IssueEventKind.opened => '${e.author} opened this issue',
    IssueEventKind.closed => '${e.author} closed this issue',
    IssueEventKind.reopened => '${e.author} reopened this issue',
    IssueEventKind.labeled => '${e.author} added the ${e.detail ?? ''} label',
    IssueEventKind.assigned => '${e.author} assigned ${e.detail ?? ''}',
    IssueEventKind.unassigned => '${e.author} unassigned ${e.detail ?? ''}',
    IssueEventKind.crossReferenced => '${e.author} referenced #${e.detail ?? ''}',
    IssueEventKind.renamed => '${e.author} renamed this to "${e.detail ?? ''}"',
    IssueEventKind.comment => '',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: e.kind == IssueEventKind.comment
                ? _CommentCard(event: e)
                : Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: TbColors.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_eventText(e), style: TbText.body(size: 12, color: TbColors.muted)),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.event});

  final IssueTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                Text(event.author, style: TbText.body(size: 12, weight: FontWeight.w700)),
                const SizedBox(width: 7),
                Text('commented', style: TbText.body(size: 12, color: TbColors.dim)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: MarkdownBody(event.bodyMarkdown),
          ),
        ],
      ),
    );
  }
}
