// lib/features/pr_detail/presentation/view/widgets/pr_reviewers_card.dart
import 'package:flutter/widgets.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/pr_reviewer.dart';

/// A card listing reviewers with their review state badges.
class PrReviewersCard extends StatelessWidget {
  const PrReviewersCard({super.key, required this.reviewers});

  final List<PrReviewer> reviewers;

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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              'REVIEWERS',
              style: TbText.label(size: 10, weight: FontWeight.w600, color: TbColors.muted, tracking: 1.4),
            ),
          ),
          if (reviewers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text('No reviewers.', style: TbText.body(size: 13, color: TbColors.muted)),
            )
          else
            for (int i = 0; i < reviewers.length; i++)
              _ReviewerRow(reviewer: reviewers[i], isLast: i == reviewers.length - 1),
        ],
      ),
    );
  }
}

class _ReviewerRow extends StatelessWidget {
  const _ReviewerRow({required this.reviewer, required this.isLast});

  final PrReviewer reviewer;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: TbColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            TbAvatarTile(login: reviewer.login),
            const SizedBox(width: 8),
            Expanded(child: Text(reviewer.login, style: TbText.body(size: 13))),
            TbBadge(
              _reviewerLabel(reviewer.state),
              _reviewerSignal(reviewer.state),
              small: true,
              tooltip: _reviewerTooltip(reviewer.state),
            ),
          ],
        ),
      ),
    );
  }
}

String _reviewerLabel(PrReviewerState s) => switch (s) {
  PrReviewerState.approved => 'Approved',
  PrReviewerState.changesRequested => 'Changes req',
  PrReviewerState.commented => 'Commented',
  PrReviewerState.pending => 'Pending',
};

TbSignal _reviewerSignal(PrReviewerState s) => switch (s) {
  PrReviewerState.approved => TbSignal.ok,
  PrReviewerState.changesRequested => TbSignal.bad,
  PrReviewerState.commented => TbSignal.info,
  PrReviewerState.pending => TbSignal.gray,
};

String _reviewerTooltip(PrReviewerState s) => switch (s) {
  PrReviewerState.approved => 'This reviewer approved the PR',
  PrReviewerState.changesRequested => 'This reviewer requested changes',
  PrReviewerState.commented => 'This reviewer commented without a verdict',
  PrReviewerState.pending => 'Review requested — not yet started',
};
