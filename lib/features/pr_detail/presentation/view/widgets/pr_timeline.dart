// lib/features/pr_detail/presentation/view/widgets/pr_timeline.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/pr_reviewer.dart';
import '../../../data/models/pr_timeline_event.dart';
import 'markdown_body.dart';

/// The activity timeline: PR opened + comments + reviews, in chronological
/// order, rendered as a vertical thread (mirrors `TurboBoard.dc.html`).
///
/// A 2px connector line runs behind a column of rows; each row is a 24px node
/// icon plus content — a **compact event row** (opened / approved / changes
/// requested) or a **comment card** (comments and reviews that carry prose).
class PrTimeline extends StatelessWidget {
  const PrTimeline({super.key, required this.events});

  final List<PrTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text('No conversation yet.', style: TbText.body(size: 13, color: TbColors.muted));
    }
    return Stack(
      children: [
        // Connector line — behind the nodes, stopping short of the last node.
        const Positioned(
          left: 11,
          top: 4,
          bottom: 24,
          child: SizedBox(width: 2, child: ColoredBox(color: TbColors.border)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < events.length; i++)
              Padding(
                // Compact events sit tighter than comment cards.
                padding: EdgeInsets.only(bottom: i == events.length - 1 ? 0 : (_isComment(events[i]) ? 12 : 10)),
                child: _TimelineRow(event: events[i]),
              ),
          ],
        ),
      ],
    );
  }
}

bool _isComment(PrTimelineEvent e) => e.kind == PrEventKind.comment || e.kind == PrEventKind.reviewComment;

/// One timeline row: node icon (24px) + content.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});

  final PrTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Node(event: event),
        const SizedBox(width: 12),
        Expanded(
          child: _isComment(event) ? _CommentCard(event: event) : _EventRow(event: event),
        ),
      ],
    );
  }
}

/// The 24px node — an avatar tile for comment cards, a colored status circle
/// for system events.
class _Node extends StatelessWidget {
  const _Node({required this.event});

  final PrTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    if (_isComment(event)) {
      // Square avatar monogram (matches the design's comment node).
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TbAvatar.bgFor(event.author),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Text(
          TbAvatar.initials(event.author),
          style: TbText.label(size: 10, weight: FontWeight.w700, color: TbColors.text, tracking: 0.2),
        ),
      );
    }

    // GitHub's merge purple — no token for it (merge button is green elsewhere).
    const mergeBg = Color(0xFF1E1433);
    const mergePurple = Color(0xFF8957E5);
    final (bg, border, icon, iconColor, square) = switch (event.kind) {
      PrEventKind.opened => (TbColors.blue, TbColors.blue, Icons.radio_button_checked, const Color(0xFFFFFFFF), false),
      PrEventKind.approved => (TbSignal.ok.bg, TbSignal.ok.border, Icons.check, TbSignal.ok.border, false),
      PrEventKind.changesRequested => (
        TbSignal.bad.bg,
        TbSignal.bad.border,
        Icons.priority_high,
        TbSignal.bad.border,
        false,
      ),
      PrEventKind.commitsPushed => (TbColors.surface2, TbColors.borderStrong, Icons.commit, TbColors.muted, true),
      PrEventKind.reviewRequested => (
        TbColors.surface2,
        TbColors.borderStrong,
        Icons.person_outline,
        TbColors.muted,
        false,
      ),
      PrEventKind.reviewRequestRemoved => (
        TbColors.surface2,
        TbColors.borderStrong,
        Icons.person_remove_outlined,
        TbColors.muted,
        false,
      ),
      PrEventKind.forcePushed => (
        TbSignal.orange.bg,
        TbSignal.orange.border,
        Icons.bolt,
        TbSignal.orange.border,
        false,
      ),
      PrEventKind.merged => (mergeBg, mergePurple, Icons.merge_type, mergePurple, false),
      PrEventKind.closed => (TbSignal.bad.bg, TbSignal.bad.border, Icons.close, TbSignal.bad.border, false),
      PrEventKind.reopened => (TbSignal.ok.bg, TbSignal.ok.border, Icons.restart_alt, TbSignal.ok.border, false),
      PrEventKind.readyForReview => (
        TbSignal.info.bg,
        TbSignal.info.border,
        Icons.visibility,
        TbSignal.info.border,
        false,
      ),
      PrEventKind.renamed => (TbColors.surface2, TbColors.borderStrong, Icons.edit_outlined, TbColors.muted, false),
      PrEventKind.labeled => (TbColors.surface2, TbColors.borderStrong, Icons.label_outline, TbColors.muted, false),
      _ => (TbColors.surface2, TbColors.borderStrong, Icons.circle, TbColors.dim, false),
    };
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(4) : null,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Icon(icon, size: 13, color: iconColor),
    );
  }
}

/// A compact single-line event ("X opened this pull request · 12M AGO").
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final PrTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final who = event.author;
    final detail = event.detail ?? '';
    final commits = int.tryParse(detail) ?? 0;
    final text = switch (event.kind) {
      PrEventKind.opened => '$who opened this pull request',
      PrEventKind.approved => '$who approved these changes',
      PrEventKind.changesRequested => '$who requested changes',
      PrEventKind.commitsPushed => '$who added ${commits == 1 ? '1 commit' : '$commits commits'}',
      PrEventKind.reviewRequested =>
        detail.isEmpty ? '$who requested a review' : '$who requested a review from $detail',
      PrEventKind.reviewRequestRemoved =>
        detail.isEmpty ? '$who removed a review request' : '$who removed the review request for $detail',
      PrEventKind.forcePushed => '$who force-pushed',
      PrEventKind.merged => '$who merged this pull request',
      PrEventKind.closed => '$who closed this pull request',
      PrEventKind.reopened => '$who reopened this pull request',
      PrEventKind.readyForReview => '$who marked this ready for review',
      PrEventKind.renamed => detail.isEmpty ? '$who changed the title' : '$who renamed this to "$detail"',
      PrEventKind.labeled => detail.isEmpty ? '$who added a label' : '$who added the $detail label',
      _ => who,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: text,
              style: TbText.body(size: 12, color: TbColors.muted, height: 1.5),
            ),
            TextSpan(
              text: '  ·  ${timeago.format(event.createdAt).toUpperCase()}',
              style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// A comment / review rendered as a card: header (author + verb-or-badge + time)
/// over a markdown body.
class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.event});

  final PrTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final badge = _badgeFor(event);
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
                Text(event.author, style: TbText.body(size: 12, weight: FontWeight.w700)),
                const SizedBox(width: 7),
                if (badge != null)
                  TbBadge(badge.$1, badge.$2, small: true)
                else
                  Text('left a comment', style: TbText.body(size: 12, color: TbColors.dim)),
                const Spacer(),
                Text(
                  timeago.format(event.createdAt).toUpperCase(),
                  style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: MarkdownBody(event.bodyMarkdown),
          ),
        ],
      ),
    );
  }
}

/// The review badge for a review comment, or null for a plain comment / a
/// commented review (which read as "left a comment").
(String, TbSignal)? _badgeFor(PrTimelineEvent event) {
  if (event.kind != PrEventKind.reviewComment) return null;
  return switch (event.reviewState) {
    PrReviewerState.approved => ('Approved', TbSignal.ok),
    PrReviewerState.changesRequested => ('Changes req', TbSignal.bad),
    _ => null,
  };
}
