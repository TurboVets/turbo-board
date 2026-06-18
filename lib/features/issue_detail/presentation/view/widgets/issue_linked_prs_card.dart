// lib/features/issue_detail/presentation/view/widgets/issue_linked_prs_card.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../pr_inbox/data/models/pr_data.dart';
import '../../../data/models/issue_detail.dart';

/// Linked pull requests with CI / review / merge signal dots. Rows tappable.
class IssueLinkedPrsCard extends StatelessWidget {
  const IssueLinkedPrsCard({super.key, required this.prs, required this.onTapPr});

  final List<LinkedPr> prs;
  final void Function(LinkedPr) onTapPr;

  static const _green = Color(0xFF54AE39);
  static const _red = Color(0xFFE94A5F);
  static const _amber = Color(0xFFFFB000);
  static const _gray = Color(0xFF45454C);

  Color _ci(PrCiState s) => switch (s) {
    PrCiState.passing => _green,
    PrCiState.failing => _red,
    PrCiState.pending => _amber,
  };

  Color _rev(PrReviewState s) => switch (s) {
    PrReviewState.approved => _green,
    PrReviewState.changesRequested => _red,
    PrReviewState.needsReview => const Color(0xFF13ACFF),
    PrReviewState.waitingOnAuthor => _gray,
  };

  (Color, String) _merge(PrLinkMergeState s) => switch (s) {
    PrLinkMergeState.merged => (const Color(0xFF8957E5), 'MERGED'),
    PrLinkMergeState.closed => (_red, 'CLOSED'),
    PrLinkMergeState.draft => (_gray, 'DRAFT'),
    PrLinkMergeState.open => (_green, 'OPEN'),
  };

  @override
  Widget build(BuildContext context) {
    if (prs.isEmpty) return const SizedBox.shrink();
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
            child: Text('LINKED PULL REQUESTS', style: TbText.label(size: 11, tracking: 1.0)),
          ),
          for (final pr in prs)
            InkWell(
              onTap: () => onTapPr(pr),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: TbColors.border)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.merge_type, size: 14, color: Color(0xFF13ACFF)),
                    const SizedBox(width: 8),
                    Text('#${pr.number}', style: TbText.label(size: 10, color: TbColors.dim)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(pr.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TbText.body(size: 13)),
                    ),
                    if (pr.isDraft) ...[const SizedBox(width: 6), TbBadge('DRAFT', TbSignal.gray, small: true)],
                    const SizedBox(width: 10),
                    TbSignalDot(color: _ci(pr.ciState), size: 8),
                    const SizedBox(width: 6),
                    TbSignalDot(color: _rev(pr.reviewState), size: 8),
                    const SizedBox(width: 6),
                    Builder(
                      builder: (_) {
                        final (c, label) = _merge(pr.mergeState);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TbSignalDot(color: c, size: 8),
                            const SizedBox(width: 4),
                            Text(label, style: TbText.label(size: 9, color: TbColors.muted)),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
