// lib/features/pr_detail/presentation/view/pr_detail_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/open_on_github_button.dart';
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

/// Read-only PR Detail, presented as a wide (~70%) overlay drawer that slides in
/// over the board with a dimming scrim. Reached via /pr/:owner/:repo/:number
/// inside the shell; tapping the scrim or ✕ closes it.
class PrDetailScreen extends ConsumerWidget {
  const PrDetailScreen({super.key, required this.owner, required this.repo, required this.number});

  static const String routeName = 'prDetail';

  final String owner;
  final String repo;
  final int number;

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(prDetailProvider(owner: owner, name: repo, number: number));
    final routeAnim = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth;
        // ~70% of the board area, clamped to a comfortable range, never wider
        // than the available space.
        final drawerW = math.min(avail * 0.96, (avail * 0.7).clamp(560.0, 1060.0));

        final body = detail.when(
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

        return Stack(
          children: [
            // Scrim over the board — tap to dismiss.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _close(context),
                child: const ColoredBox(color: Color(0x73000000)),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: routeAnim, curve: Curves.easeOutCubic)),
                child: _DrawerPanel(width: drawerW, onClose: () => _close(context), child: body),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The right-aligned drawer chrome: a 58px header bar with title + close, and a
/// scrollable body that holds the detail (or its loading/error state).
class _DrawerPanel extends StatelessWidget {
  const _DrawerPanel({required this.width, required this.onClose, required this.child});

  final double width;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: TbColors.surface,
        border: Border(left: BorderSide(color: TbColors.border)),
        boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 100, offset: Offset(-40, 0))],
      ),
      child: Column(
        children: [
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                Text('PR DETAIL', style: TbText.label(size: 12, weight: FontWeight.w600, tracking: 1.7)),
                const Spacer(),
                _CloseButton(onTap: onClose),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: _hover ? TbColors.borderStrong : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('✕', style: TbText.body(size: 15, color: _hover ? TbColors.text : TbColors.muted)),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final PrDetail detail;

  @override
  Widget build(BuildContext context) {
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderSection(detail: detail),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return Column(children: [main, const SizedBox(height: 16), aside]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: main),
                  const SizedBox(width: 18),
                  SizedBox(width: 322, child: aside),
                ],
              );
            },
          ),
        ],
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
        // Repo line + Open on GitHub action
        Row(
          children: [
            TbSignalDot(color: TbRepoColor.forSlug(repoSlug), size: 7),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                repoSlug,
                style: TbText.label(size: 11, color: TbColors.muted, tracking: 0.6),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (detail.url != null) ...[const SizedBox(width: 12), OpenOnGitHubButton.labeled(url: detail.url!)],
          ],
        ),
        const SizedBox(height: 8),
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
