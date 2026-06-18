// lib/features/issue_detail/presentation/view/issue_detail_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../shared/ui/theme/tb_breakpoints.dart';
import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/widgets/open_on_github_button.dart';
import '../../../../shared/ui/widgets/tb_badge.dart';
import '../../../ai/presentation/view/widgets/issue_next_action_card.dart';
import '../../../ai/presentation/view/widgets/issue_summary_card.dart';
import '../../data/models/issue_detail.dart';
import '../providers/issue_detail_provider.dart';
import 'widgets/issue_comment_composer.dart';
import 'widgets/issue_description_card.dart';
import 'widgets/issue_development_card.dart';
import 'widgets/issue_linked_prs_card.dart';
import 'widgets/issue_sidebar_fields.dart';
import 'widgets/issue_sub_issues_card.dart';
import 'widgets/issue_timeline.dart';

/// Read-only Issue Detail, presented as a wide (~70%) overlay drawer that slides in
/// over the board with a dimming scrim. Reached via /issue/:owner/:repo/:number
/// inside the shell; tapping the scrim or ✕ closes it.
class IssueDetailScreen extends ConsumerWidget {
  const IssueDetailScreen({super.key, required this.owner, required this.repo, required this.number});

  static const String routeName = 'issueDetail';

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
    final detail = ref.watch(issueDetailProvider(owner: owner, repo: repo, number: number));
    final routeAnim = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth;
        // Phone: take nearly the whole width. Otherwise ~70% of the board area,
        // clamped to a comfortable range, never wider than the available space.
        final drawerW = avail < TbBreakpoints.mobile
            ? avail * 0.96
            : math.min(avail * 0.96, (avail * 0.7).clamp(560.0, 1060.0));

        final body = detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TbBadge('ERROR', TbSignal.bad),
                const SizedBox(height: 12),
                Text('Could not load issue.\n$err', textAlign: TextAlign.center, style: TbText.body(size: 14)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => ref.invalidate(issueDetailProvider(owner: owner, repo: repo, number: number)),
                  child: Text('Retry', style: TbText.body(size: 14, color: TbColors.cyan)),
                ),
              ],
            ),
          ),
          data: (d) => _DetailBody(
            detail: d,
            onTapRef: (ref_) => context.pushNamed(
              routeName,
              pathParameters: {
                'owner': ref_.repo.split('/').first,
                'repo': ref_.repo.split('/').length > 1 ? ref_.repo.split('/')[1] : '',
                'number': ref_.number.toString(),
              },
            ),
            onTapPr: (pr) => context.pushNamed(
              'prDetail',
              pathParameters: {'owner': pr.owner, 'repo': pr.repo, 'number': pr.number.toString()},
            ),
            onTapSub: (s) {
              final parts = d.repo.split('/');
              if (parts.length == 2) {
                context.pushNamed(
                  routeName,
                  pathParameters: {'owner': parts[0], 'repo': parts[1], 'number': s.number.toString()},
                );
              }
            },
          ),
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
                  number: number,
                  onClose: () => _close(context),
                  onRefresh: () => ref.invalidate(issueDetailProvider(owner: owner, repo: repo, number: number)),
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
  const _DrawerPanel({
    required this.width,
    required this.number,
    required this.onClose,
    required this.onRefresh,
    required this.child,
  });

  final double width;
  final int number;
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
      child: Material(
        color: TbColors.surface,
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
                  Text('ISSUE  #$number', style: TbText.label(size: 12, weight: FontWeight.w600, tracking: 1.7)),
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
  const _DetailBody({required this.detail, required this.onTapRef, required this.onTapPr, required this.onTapSub});

  final IssueDetail detail;
  final void Function(IssueRef) onTapRef;
  final void Function(LinkedPr) onTapPr;
  final void Function(SubIssue) onTapSub;

  @override
  Widget build(BuildContext context) {
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IssueDescriptionCard(issue: detail),
        const SizedBox(height: 16),
        IssueSubIssuesCard(issue: detail, onTapSub: onTapSub),
        if (detail.linkedPrs.isNotEmpty) ...[
          const SizedBox(height: 16),
          IssueLinkedPrsCard(prs: detail.linkedPrs, onTapPr: onTapPr),
        ],
        const SizedBox(height: 16),
        Text('ACTIVITY', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4)),
        const SizedBox(height: 8),
        IssueTimeline(events: detail.timeline),
        const SizedBox(height: 8),
        IssueCommentComposer(issue: detail),
      ],
    );

    final aside = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IssueSummaryCard(issue: detail),
        const SizedBox(height: 12),
        IssueNextActionCard(issue: detail),
        const SizedBox(height: 12),
        IssueSidebarFields(issue: detail, onTapRef: onTapRef),
        const SizedBox(height: 12),
        IssueDevelopmentCard(issue: detail),
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [aside, const SizedBox(height: 16), main],
                );
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

  final IssueDetail detail;

  @override
  Widget build(BuildContext context) {
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
            if (detail.url != null) OpenOnGitHubButton.labeled(url: detail.url!),
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
            // Author row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TbAvatarTile(login: detail.author),
                const SizedBox(width: 6),
                Text(detail.author, style: TbText.body(size: 12, color: TbColors.muted)),
              ],
            ),
            // Comment count
            if (detail.commentCount > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.comment_outlined, size: 12, color: TbColors.muted),
                  const SizedBox(width: 4),
                  Text('${detail.commentCount}', style: TbText.body(size: 12, color: TbColors.muted)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

String _stateBadgeLabel(IssueDetail d) => switch (d.state) {
  IssueState.open => 'Open',
  IssueState.closed => 'Closed',
};

TbSignal _stateBadgeSignal(IssueDetail d) => switch (d.state) {
  IssueState.open => TbSignal.ok,
  IssueState.closed => TbSignal.bad,
};
