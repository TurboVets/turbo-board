// lib/features/pr_detail/presentation/view/widgets/pr_checks_panel.dart
import 'package:flutter/material.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../data/models/pr_check.dart';

/// A panel listing CI checks with a signal dot per check.
class PrChecksPanel extends StatelessWidget {
  const PrChecksPanel({super.key, required this.checks});

  final List<PrCheck> checks;

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
            child: Text('Checks', style: text.titleSmall),
          ),
          if (checks.isEmpty)
            Text('No checks reported.', style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted))
          else
            for (final c in checks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    TetherSignalDot(color: _dotColor(c.state), size: 8),
                    const SizedBox(width: 10),
                    Expanded(child: Text(c.name, style: text.bodySmall)),
                    if (c.summary != null)
                      Text(c.summary!, style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

TetherBadgeColor _dotColor(PrCheckState s) => switch (s) {
  PrCheckState.success => TetherBadgeColor.green,
  PrCheckState.pending => TetherBadgeColor.yellow,
  PrCheckState.failure => TetherBadgeColor.red,
  PrCheckState.neutral => TetherBadgeColor.gray,
};
