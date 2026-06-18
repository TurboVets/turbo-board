// lib/features/issue_detail/presentation/view/widgets/issue_description_card.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../pr_detail/presentation/view/widgets/markdown_body.dart';
import '../../../data/models/issue_detail.dart';

/// The issue body as a card: author header over the markdown body. MarkdownBody
/// already renders task-list checkboxes, fenced code, and tables.
class IssueDescriptionCard extends StatelessWidget {
  const IssueDescriptionCard({super.key, required this.issue});

  final IssueDetail issue;

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
                Text(issue.author, style: TbText.body(size: 12, weight: FontWeight.w700)),
                const SizedBox(width: 7),
                Text('opened this issue', style: TbText.body(size: 12, color: TbColors.dim)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: MarkdownBody(issue.bodyMarkdown),
          ),
        ],
      ),
    );
  }
}
