// lib/features/issue_detail/presentation/view/widgets/issue_comment_composer.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../data/models/issue_detail.dart';
import '../../providers/issue_composer_provider.dart';

/// Comment box with Close/Reopen and Comment actions. Renders a read-only
/// notice when [issue.viewerCanUpdate] is false.
class IssueCommentComposer extends HookConsumerWidget {
  const IssueCommentComposer({super.key, required this.issue});

  final IssueDetail issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!issue.viewerCanUpdate) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "You don't have write access to comment on this issue.",
          style: TbText.body(size: 12, color: TbColors.muted),
        ),
      );
    }
    final parts = issue.repo.split('/');
    final owner = parts.first;
    final name = parts.length > 1 ? parts[1] : '';
    final controller = useTextEditingController();
    final state = ref.watch(issueComposerProvider(owner: owner, name: name, number: issue.number));
    final notifier = ref.read(issueComposerProvider(owner: owner, name: name, number: issue.number).notifier);
    final busy = state is AsyncLoading;
    final id = issue.id;

    Future<void> submitComment() async {
      if (id == null || controller.text.trim().isEmpty) return;
      final ok = await notifier.comment(id, controller.text.trim());
      if (ok) controller.clear();
    }

    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              style: TbText.body(size: 13, color: TbColors.text),
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Leave a comment…'),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                Text('Markdown supported', style: TbText.label(size: 9, color: TbColors.muted)),
                const Spacer(),
                TextButton(
                  onPressed: busy || id == null
                      ? null
                      : () => issue.isClosed ? notifier.reopen(id) : notifier.close(id),
                  child: Text(issue.isClosed ? 'Reopen issue' : 'Close issue'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: busy ? null : submitComment, child: const Text('Comment')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
