// lib/features/pr_detail/presentation/view/widgets/pr_commit_card.dart
import 'package:flutter/widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../data/models/pr_commit.dart';

/// A card showing the last commit SHA, message headline and relative date.
class PrCommitCard extends StatelessWidget {
  const PrCommitCard({super.key, required this.commit});

  final PrCommit commit;

  @override
  Widget build(BuildContext context) {
    final relativeDate = commit.committedDate == null ? null : timeago.format(commit.committedDate!);

    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            // SHA chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: TbColors.surface2, borderRadius: BorderRadius.circular(2)),
              child: Text(commit.abbreviatedOid, style: TbText.label(size: 12, color: TbColors.text, tracking: 0.4)),
            ),
            const SizedBox(width: 10),
            // Message headline
            Expanded(
              child: Text(
                commit.messageHeadline,
                style: TbText.body(size: 13, color: TbColors.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (relativeDate != null) ...[
              const SizedBox(width: 8),
              Text(relativeDate, style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.5)),
            ],
          ],
        ),
      ),
    );
  }
}
