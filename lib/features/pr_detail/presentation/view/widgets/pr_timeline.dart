// lib/features/pr_detail/presentation/view/widgets/pr_timeline.dart
import 'package:flutter/widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/pr_reviewer.dart';
import '../../../data/models/pr_timeline_event.dart';
import 'markdown_body.dart';

/// The conversation timeline: comments + review summaries, in order.
class PrTimeline extends StatelessWidget {
  const PrTimeline({super.key, required this.events});

  final List<PrTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text('No conversation yet.', style: TbText.body(size: 13, color: TbColors.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < events.length; i++) ...[
          PrTimelineTile(event: events[i]),
          if (i < events.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// A single timeline event rendered as a card with header bar + body.
class PrTimelineTile extends StatelessWidget {
  const PrTimelineTile({super.key, required this.event});

  final PrTimelineEvent event;

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
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                TbAvatarTile(login: event.author),
                const SizedBox(width: 8),
                Text(event.author, style: TbText.body(size: 13, weight: FontWeight.w600)),
                if (event.kind == PrEventKind.review && event.reviewState != null) ...[
                  const SizedBox(width: 8),
                  TbBadge(_reviewLabel(event.reviewState!), _reviewSignal(event.reviewState!), small: true),
                ],
                const Spacer(),
                Text(
                  timeago.format(event.createdAt),
                  style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.5),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: MarkdownBody(event.bodyMarkdown),
          ),
        ],
      ),
    );
  }
}

String _reviewLabel(PrReviewerState s) => switch (s) {
  PrReviewerState.approved => 'Approved',
  PrReviewerState.changesRequested => 'Changes req',
  PrReviewerState.commented => 'Commented',
  PrReviewerState.pending => 'Pending',
};

TbSignal _reviewSignal(PrReviewerState s) => switch (s) {
  PrReviewerState.approved => TbSignal.ok,
  PrReviewerState.changesRequested => TbSignal.bad,
  PrReviewerState.commented => TbSignal.info,
  PrReviewerState.pending => TbSignal.gray,
};
