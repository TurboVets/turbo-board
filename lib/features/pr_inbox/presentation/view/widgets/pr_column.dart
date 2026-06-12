// lib/features/pr_inbox/presentation/view/widgets/pr_column.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../data/models/pr_data.dart';
import 'pr_card.dart';

/// One board column: a 2px top accent, header (label + count), scrollable cards.
///
/// Fills the height it is given (it uses [Expanded] internally), so the parent
/// MUST constrain its height — the board wraps each column in a height-bounded
/// `SizedBox`. In tests, a `Scaffold` body provides that bound.
class PrColumn extends StatelessWidget {
  const PrColumn({
    super.key,
    required this.title,
    required this.prs,
    this.accent = TbBoard.needsReview,
    this.onCardTap,
  });

  final String title;
  final List<PrData> prs;

  /// Top-accent color (2px border at top of column).
  final Color accent;

  final void Function(PrData pr)? onCardTap;

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
          // 2px top accent
          Container(height: 2, color: accent),
          // Header row
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                Text(title, style: TbText.label(size: 11, color: TbColors.text, tracking: 1.0)),
                const Spacer(),
                Text(
                  '${prs.length}',
                  style: TbText.label(size: 13, weight: FontWeight.w700, color: TbColors.muted, tracking: 0.2),
                ),
              ],
            ),
          ),
          // Card list
          Expanded(
            child: prs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text('NOTHING HERE', style: TbText.label(size: 11, color: TbColors.dim, tracking: 0.8)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: prs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        PrCard(pr: prs[i], onTap: onCardTap == null ? null : () => onCardTap!(prs[i])),
                  ),
          ),
        ],
      ),
    );
  }
}
