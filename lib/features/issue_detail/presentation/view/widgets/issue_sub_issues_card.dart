// lib/features/issue_detail/presentation/view/widgets/issue_sub_issues_card.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../lead_cockpit/presentation/helpers/cockpit_palette.dart';
import '../../../data/models/issue_detail.dart';

/// Sub-issue task list with a done/total progress bar. Rows are tappable.
class IssueSubIssuesCard extends StatelessWidget {
  const IssueSubIssuesCard({super.key, required this.issue, required this.onTapSub});

  final IssueDetail issue;
  final void Function(SubIssue) onTapSub;

  @override
  Widget build(BuildContext context) {
    if (!issue.hasSubIssues) return const SizedBox.shrink();
    final pct = issue.subTotal == 0 ? 0.0 : issue.subDone / issue.subTotal;
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                Text('SUB-ISSUES', style: TbText.label(size: 11, tracking: 1.0)),
                const SizedBox(width: 10),
                Text('${issue.subDone}/${issue.subTotal} done', style: TbText.label(size: 10, color: TbColors.muted)),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: TbColors.canvas,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF54AE39)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final s in issue.subIssues)
            InkWell(
              onTap: () => onTapSub(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: TbColors.border)),
                ),
                child: Row(
                  children: [
                    Icon(
                      s.done ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 15,
                      color: s.done ? const Color(0xFF54AE39) : TbColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Text('#${s.number}', style: TbText.label(size: 10, color: TbColors.dim)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TbText.body(
                          size: 13,
                          color: s.done ? TbColors.muted : TbColors.text,
                        ).copyWith(decoration: s.done ? TextDecoration.lineThrough : null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TbBadge(CockpitPalette.statusLabel(s.status), TbSignal.gray, small: true),
                    if (s.assignee != null) ...[const SizedBox(width: 8), TbAvatarTile(login: s.assignee!, size: 19)],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
