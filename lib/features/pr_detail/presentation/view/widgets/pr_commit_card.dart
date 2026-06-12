import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turbo_ui/turbo_ui.dart';

import '../../../data/models/pr_commit.dart';

class PrCommitCard extends StatelessWidget {
  const PrCommitCard({super.key, required this.commit});

  final PrCommit commit;

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
            child: Text('Last commit', style: text.titleSmall),
          ),
          Text(commit.messageHeadline, style: text.bodySmall),
          const SizedBox(height: 4),
          Text(
            commit.committedDate == null
                ? commit.abbreviatedOid
                : '${commit.abbreviatedOid} · ${timeago.format(commit.committedDate!)}',
            style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted),
          ),
        ],
      ),
    );
  }
}
