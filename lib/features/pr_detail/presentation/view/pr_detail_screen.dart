// lib/features/pr_detail/presentation/view/pr_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../shared/ui/theme/tb_breakpoints.dart';
import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/open_in_github_desktop_button.dart';
import '../../../../shared/ui/widgets/open_on_github_button.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../../ai/presentation/view/widgets/pr_summary_card.dart';
import '../../../ai/presentation/view/widgets/reply_drafter.dart';
import '../../../issue_detail/data/models/issue_detail.dart' show IssueRef;
import '../../data/models/pr_detail.dart';
import '../../../pr_inbox/data/models/pr_data.dart' show PrReviewState;
import '../providers/pr_detail_provider.dart';
import 'widgets/pr_checks_panel.dart';
import 'widgets/pr_comment_composer.dart';
import 'widgets/pr_commit_card.dart';
import 'widgets/pr_reviewers_card.dart';
import 'widgets/pr_timeline.dart';
import 'widgets/markdown_body.dart';

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
        // Fill the whole content area, right up to the side nav rail (the shell
        // sits outside this LayoutBuilder, so maxWidth already excludes the rail).
        final drawerW = constraints.maxWidth;

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
                child: _DrawerPanel(
                  width: drawerW,
                  onClose: () => _close(context),
                  onRefresh: () => ref.invalidate(prDetailProvider(owner: owner, name: repo, number: number)),
                  child: body,
                ),
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
  const _DrawerPanel({required this.width, required this.onClose, required this.onRefresh, required this.child});

  final double width;
  final VoidCallback onClose;
  final VoidCallback onRefresh;
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
                _HeaderIconButton(icon: LucideIcons.refreshCw, tooltip: 'Refresh', onTap: onRefresh),
                const SizedBox(width: 4),
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

class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
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
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: _hover ? TbColors.borderStrong : Colors.transparent),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(widget.icon, size: 14, color: _hover ? TbColors.text : TbColors.muted),
          ),
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
    final hasDescription = detail.bodyMarkdown.trim().isNotEmpty;
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrChecksPanel(checks: detail.checks),
        const SizedBox(height: 16),
        if (hasDescription) ...[
          Text('DESCRIPTION', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4)),
          const SizedBox(height: 8),
          _DescriptionCard(detail: detail),
          const SizedBox(height: 16),
        ],
        Text('CONVERSATION', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4)),
        const SizedBox(height: 8),
        PrTimeline(events: detail.timeline),
        PrCommentComposer(detail: detail),
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
        if (detail.linkedIssues.isNotEmpty) ...[
          const SizedBox(height: 12),
          _LinkedIssuesCard(issues: detail.linkedIssues),
        ],
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

/// The PR description (body) rendered as a card, styled like a timeline comment:
/// author header over the markdown body. GitHub shows this as the opening post.
class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.detail});

  final PrDetail detail;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                Text(detail.author, style: TbText.body(size: 12, weight: FontWeight.w700)),
                const SizedBox(width: 7),
                Text('opened this pull request', style: TbText.body(size: 12, color: TbColors.dim)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: MarkdownBody(detail.bodyMarkdown),
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
            const SizedBox(width: 12),
            OpenInGitHubDesktopButton(
              repo: detail.repo,
              headRefName: detail.headRefName,
              number: detail.number,
              isCrossRepository: detail.isCrossRepository,
              compact: context.isMobile,
            ),
            if (detail.url != null) ...[
              const SizedBox(width: 8),
              OpenOnGitHubButton.filesLabeled(prUrl: detail.url!),
              const SizedBox(width: 8),
              OpenOnGitHubButton.labeled(url: detail.url!),
            ],
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

class _LinkedIssuesCard extends StatelessWidget {
  const _LinkedIssuesCard({required this.issues});
  final List<IssueRef> issues;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Text(
              'LINKED ISSUES',
              style: TbText.label(size: 10, weight: FontWeight.w600, color: TbColors.muted, tracking: 1.4),
            ),
          ),
          for (int idx = 0; idx < issues.length; idx++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: idx == issues.length - 1 ? null : const Border(bottom: BorderSide(color: TbColors.border)),
              ),
              child: InkWell(
                onTap: () {
                  final p = issues[idx].repo.split('/');
                  if (p.length == 2) context.push('/issue/${p[0]}/${p[1]}/${issues[idx].number}');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  child: Row(
                    children: [
                      Text('#${issues[idx].number}', style: TbText.label(size: 10, color: TbColors.dim)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          issues[idx].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TbText.body(size: 13, color: TbColors.cyan),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
