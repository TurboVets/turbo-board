// lib/features/pr_detail/presentation/view/widgets/pr_timeline.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turbo_ui/turbo_ui.dart';

import '../../../data/models/pr_reviewer.dart';
import '../../../data/models/pr_timeline_event.dart';
import 'markdown_body.dart';

/// The conversation timeline: comments + review summaries, in order.
class PrTimeline extends StatelessWidget {
  const PrTimeline({super.key, required this.events});

  final List<PrTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (events.isEmpty) {
      return Text(
        'No conversation yet.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.foreground.primaryMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PrTimelineTile(event: e),
          ),
      ],
    );
  }
}

class PrTimelineTile extends StatelessWidget {
  const PrTimelineTile({super.key, required this.event});

  final PrTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return TetherCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(event.author, style: text.labelLarge),
              const SizedBox(width: 8),
              if (event.kind == PrEventKind.review && event.reviewState != null)
                TetherBadge(
                  label: _reviewLabel(event.reviewState!),
                  color: _reviewColor(event.reviewState!),
                  size: TetherBadgeSize.small,
                ),
              const Spacer(),
              Text(
                timeago.format(event.createdAt),
                style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownBody(event.bodyMarkdown),
        ],
      ),
    );
  }
}

String _reviewLabel(PrReviewerState s) => switch (s) {
  PrReviewerState.approved => 'Approved',
  PrReviewerState.changesRequested => 'Changes requested',
  PrReviewerState.commented => 'Commented',
  PrReviewerState.pending => 'Pending',
};

TetherBadgeColor _reviewColor(PrReviewerState s) => switch (s) {
  PrReviewerState.approved => TetherBadgeColor.green,
  PrReviewerState.changesRequested => TetherBadgeColor.red,
  PrReviewerState.commented => TetherBadgeColor.blue,
  PrReviewerState.pending => TetherBadgeColor.gray,
};
