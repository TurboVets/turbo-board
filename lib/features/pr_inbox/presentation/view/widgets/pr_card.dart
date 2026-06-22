// lib/features/pr_inbox/presentation/view/widgets/pr_card.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/open_on_github_button.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/pr_data.dart';

/// A single PR card on the board.
class PrCard extends StatelessWidget {
  const PrCard({super.key, required this.pr, this.onTap});

  final PrData pr;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Conflicting PRs are highlighted with an orange border + faint tint so they
    // stand out on the board, matching the inline CONFLICTS badge.
    final conflicting = pr.mergeState == PrMergeState.conflicting;
    return GestureDetector(
      onTap: onTap,
      // Drafts are dimmed to read as not-yet-active work on the board.
      child: Opacity(
        opacity: pr.isDraft ? 0.55 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: conflicting ? TbSignal.orange.bg : TbColors.surface2,
            border: Border.all(color: conflicting ? TbSignal.orange.border : TbColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Repo line: signal dot + slug + #num
              Row(
                children: [
                  TbSignalDot(color: TbRepoColor.forSlug(pr.repo), size: 9),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: pr.repo),
                          TextSpan(
                            text: ' #${pr.number}',
                            style: TbText.label(
                              size: 10,
                              weight: FontWeight.w600,
                              color: TbColors.muted,
                              tracking: 0.5,
                            ),
                          ),
                        ],
                        style: TbText.label(size: 10, weight: FontWeight.w500, color: TbColors.muted, tracking: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (pr.htmlUrl != null) ...[const SizedBox(width: 6), OpenOnGitHubButton.icon(url: pr.htmlUrl!)],
                ],
              ),
              const SizedBox(height: 7),
              // Title (with optional Draft badge inline before it)
              Text.rich(
                TextSpan(
                  children: [
                    if (pr.isDraft) ...[
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: TbColors.surface2,
                            border: Border.all(color: const Color(0x73BABBBF)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DRAFT',
                            style: TbText.label(
                              size: 10,
                              weight: FontWeight.w500,
                              color: TbColors.muted,
                              tracking: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                    TextSpan(
                      text: pr.title,
                      style: TbText.body(size: 13, weight: FontWeight.w600, color: TbColors.text, height: 1.4),
                    ),
                  ],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // CI + review badges
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  TbBadge(_ciLabel(pr.ciState), _ciSignal(pr.ciState), tooltip: _ciTooltip(pr.ciState)),
                  // Drafts aren't up for review yet — show WAITING regardless of
                  // GitHub's review decision so the badge matches the board column.
                  Builder(
                    builder: (_) {
                      final review = pr.isDraft ? PrReviewState.waitingOnAuthor : pr.reviewState;
                      return TbBadge(_reviewLabel(review), _reviewSignal(review), tooltip: _reviewTooltip(review));
                    },
                  ),
                  if (pr.mergeState == PrMergeState.conflicting)
                    const TbBadge(
                      '⚠ CONFLICTS',
                      TbSignal.orange,
                      tooltip: 'Has merge conflicts with the destination branch',
                    ),
                ],
              ),
              const SizedBox(height: 11),
              // Footer: avatar tile + author · updated · Nc
              Row(
                children: [
                  TbAvatarTile(login: pr.author, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${pr.author} · ${timeago.format(pr.updatedAt)}${pr.commentsCount > 0 ? ' · ${pr.commentsCount}c' : ''}',
                      style: TbText.label(size: 10, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _ciLabel(PrCiState s) => switch (s) {
  PrCiState.passing => '✓ CHECKS',
  PrCiState.pending => '● CHECKS',
  PrCiState.failing => '✕ CHECKS',
};

TbSignal _ciSignal(PrCiState s) => switch (s) {
  PrCiState.passing => TbSignal.ok,
  PrCiState.pending => TbSignal.warn,
  PrCiState.failing => TbSignal.bad,
};

String _ciTooltip(PrCiState s) => switch (s) {
  PrCiState.passing => 'CI checks passed',
  PrCiState.pending => 'CI checks are still running',
  PrCiState.failing => 'One or more CI checks failed',
};

String _reviewLabel(PrReviewState s) => switch (s) {
  PrReviewState.needsReview => 'NEEDS REVIEW',
  PrReviewState.changesRequested => 'CHANGES REQ',
  PrReviewState.approved => 'APPROVED',
  PrReviewState.waitingOnAuthor => 'WAITING',
};

TbSignal _reviewSignal(PrReviewState s) => switch (s) {
  PrReviewState.needsReview => TbSignal.info,
  PrReviewState.changesRequested => TbSignal.bad,
  PrReviewState.approved => TbSignal.ok,
  PrReviewState.waitingOnAuthor => TbSignal.gray,
};

String _reviewTooltip(PrReviewState s) => switch (s) {
  PrReviewState.needsReview => 'Waiting for a review',
  PrReviewState.changesRequested => 'A reviewer requested changes — back to the author',
  PrReviewState.approved => 'Approved and ready to merge',
  PrReviewState.waitingOnAuthor => 'Waiting on the author to respond',
};
