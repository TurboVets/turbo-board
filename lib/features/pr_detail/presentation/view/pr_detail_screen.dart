// lib/features/pr_detail/presentation/view/pr_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../../ai/presentation/view/widgets/pr_summary_card.dart';
import '../../../ai/presentation/view/widgets/reply_drafter.dart';
import '../../data/models/pr_detail.dart';
import '../../../pr_inbox/data/models/pr_data.dart' show PrReviewState;
import '../providers/pr_detail_provider.dart';
import 'widgets/pr_checks_panel.dart';
import 'widgets/pr_commit_card.dart';
import 'widgets/pr_reviewers_card.dart';
import 'widgets/pr_timeline.dart';

/// Read-only PR Detail. Reached via /pr/:owner/:repo/:number inside the shell.
class PrDetailScreen extends ConsumerWidget {
  const PrDetailScreen({super.key, required this.owner, required this.repo, required this.number});

  static const String routeName = 'prDetail';

  final String owner;
  final String repo;
  final int number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(prDetailProvider(owner: owner, name: repo, number: number));

    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TbBadge('ERROR', TbSignal.bad),
            const SizedBox(height: 12),
            Text('Could not load PR.\n$err', textAlign: TextAlign.center, style: TbText.body(size: 14)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.invalidate(prDetailProvider(owner: owner, name: repo, number: number)),
              child: Text('Retry', style: TbText.body(size: 14, color: TbColors.cyan)),
            ),
          ],
        ),
      ),
      data: (d) => _DetailBody(detail: d),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final PrDetail detail;

  @override
  Widget build(BuildContext context) {
    final header = _HeaderSection(detail: detail);

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 16),
        PrChecksPanel(checks: detail.checks),
        const SizedBox(height: 16),
        Text('CONVERSATION', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4)),
        const SizedBox(height: 8),
        PrTimeline(events: detail.timeline),
      ],
    );

    final aside = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrSummaryCard(detail: detail),
        const SizedBox(height: 12),
        ReplyDrafter(detail: detail),
        const SizedBox(height: 12),
        PrReviewersCard(reviewers: detail.reviewers),
        if (detail.lastCommit != null) ...[const SizedBox(height: 12), PrCommitCard(commit: detail.lastCommit!)],
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Column(children: [main, const SizedBox(height: 16), aside]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: main),
                  const SizedBox(width: 24),
                  SizedBox(width: 280, child: aside),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.detail});

  final PrDetail detail;

  @override
  Widget build(BuildContext context) {
    // Parse repo slug for the signal dot (the detail.repo is "owner/name")
    final repoSlug = detail.repo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back nav
        GestureDetector(
          onTap: () => context.go('/'),
          child: Text('← Back to board', style: TbText.label(size: 11, color: TbColors.cyan, tracking: 0.6)),
        ),
        const SizedBox(height: 10),
        // Repo line
        Row(
          children: [
            TbSignalDot(color: TbRepoColor.forSlug(repoSlug), size: 7),
            const SizedBox(width: 6),
            Text(repoSlug, style: TbText.label(size: 11, color: TbColors.muted, tracking: 0.6)),
          ],
        ),
        const SizedBox(height: 6),
        // Title + number
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(detail.title, style: TbText.body(size: 18, weight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            Text(
              '  #${detail.number}',
              style: TbText.body(size: 18, weight: FontWeight.w700, color: TbColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Badge row
        Wrap(
          spacing: 7,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // State badge
            TbBadge(_stateBadgeLabel(detail), _stateBadgeSignal(detail), small: true),
            // Review decision badge (optional)
            if (detail.reviewDecision != null)
              TbBadge(
                _reviewDecisionLabel(detail.reviewDecision!),
                _reviewDecisionSignal(detail.reviewDecision!),
                small: true,
              ),
            // Author row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TbAvatarTile(login: detail.author),
                const SizedBox(width: 6),
                Text('${detail.author} → ${detail.baseRefName}', style: TbText.body(size: 12, color: TbColors.muted)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

String _stateBadgeLabel(PrDetail d) => d.isDraft
    ? 'Draft'
    : switch (d.state) {
        PrState.open => 'Open',
        PrState.merged => 'Merged',
        PrState.closed => 'Closed',
      };

TbSignal _stateBadgeSignal(PrDetail d) => d.isDraft
    ? TbSignal.gray
    : switch (d.state) {
        PrState.open => TbSignal.ok,
        PrState.merged => TbSignal.info,
        PrState.closed => TbSignal.bad,
      };

String _reviewDecisionLabel(PrReviewState s) => switch (s) {
  PrReviewState.needsReview => 'NEEDS REVIEW',
  PrReviewState.changesRequested => 'CHANGES REQ',
  PrReviewState.approved => 'APPROVED',
  PrReviewState.waitingOnAuthor => 'WAITING',
};

TbSignal _reviewDecisionSignal(PrReviewState s) => switch (s) {
  PrReviewState.needsReview => TbSignal.info,
  PrReviewState.changesRequested => TbSignal.bad,
  PrReviewState.approved => TbSignal.ok,
  PrReviewState.waitingOnAuthor => TbSignal.gray,
};
