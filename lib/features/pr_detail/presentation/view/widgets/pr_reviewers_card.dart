import 'package:flutter/material.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../data/models/pr_reviewer.dart';

class PrReviewersCard extends StatelessWidget {
  const PrReviewersCard({super.key, required this.reviewers});

  final List<PrReviewer> reviewers;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    return TetherCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Reviewers', style: text.titleSmall),
          ),
          if (reviewers.isEmpty)
            Text('No reviewers.', style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted))
          else
            for (final r in reviewers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(r.login, style: text.bodySmall)),
                    TetherBadge(label: _label(r.state), color: _color(r.state), size: TetherBadgeSize.small),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

String _label(PrReviewerState s) => switch (s) {
  PrReviewerState.approved => 'Approved',
  PrReviewerState.changesRequested => 'Changes req',
  PrReviewerState.commented => 'Commented',
  PrReviewerState.pending => 'Pending',
};

TetherBadgeColor _color(PrReviewerState s) => switch (s) {
  PrReviewerState.approved => TetherBadgeColor.green,
  PrReviewerState.changesRequested => TetherBadgeColor.red,
  PrReviewerState.commented => TetherBadgeColor.blue,
  PrReviewerState.pending => TetherBadgeColor.gray,
};
