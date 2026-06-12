// lib/features/pr_inbox/presentation/view/widgets/pr_card.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turbo_ui/turbo_ui.dart';

import '../../../data/models/pr_data.dart';

/// A single PR row on the board. Display-only in sub-project B (tap is a no-op;
/// PR Detail arrives in sub-project D).
class PrCard extends StatelessWidget {
  const PrCard({super.key, required this.pr});

  final PrData pr;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return TetherCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                pr.isDraft ? LucideIcons.gitPullRequestDraft : LucideIcons.gitPullRequest,
                size: 18,
                color: colors.foreground.link,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(pr.title, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${pr.slug} · ${pr.author} · ${timeago.format(pr.updatedAt)}',
            style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TetherBadge(label: _ciLabel(pr.ciState), color: _ciColor(pr.ciState), size: TetherBadgeSize.small),
              TetherBadge(
                label: _reviewLabel(pr.reviewState),
                color: _reviewColor(pr.reviewState),
                size: TetherBadgeSize.small,
              ),
              if (pr.commentsCount > 0)
                TetherBadge(
                  label: '${pr.commentsCount}',
                  icon: LucideIcons.messageSquare,
                  color: TetherBadgeColor.gray,
                  size: TetherBadgeSize.small,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _ciLabel(PrCiState s) => switch (s) {
  PrCiState.passing => 'Checks',
  PrCiState.pending => 'Checks',
  PrCiState.failing => 'Checks',
};

TetherBadgeColor _ciColor(PrCiState s) => switch (s) {
  PrCiState.passing => TetherBadgeColor.green,
  PrCiState.pending => TetherBadgeColor.yellow,
  PrCiState.failing => TetherBadgeColor.red,
};

String _reviewLabel(PrReviewState s) => switch (s) {
  PrReviewState.needsReview => 'Needs review',
  PrReviewState.changesRequested => 'Changes req',
  PrReviewState.approved => 'Approved',
  PrReviewState.waitingOnAuthor => 'Waiting',
};

TetherBadgeColor _reviewColor(PrReviewState s) => switch (s) {
  PrReviewState.needsReview => TetherBadgeColor.blue,
  PrReviewState.changesRequested => TetherBadgeColor.red,
  PrReviewState.approved => TetherBadgeColor.green,
  PrReviewState.waitingOnAuthor => TetherBadgeColor.gray,
};
