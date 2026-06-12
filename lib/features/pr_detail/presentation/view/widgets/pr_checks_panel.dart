// lib/features/pr_detail/presentation/view/widgets/pr_checks_panel.dart
import 'package:flutter/widgets.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/pr_check.dart';

/// A card listing CI checks with a signal dot per check.
class PrChecksPanel extends StatelessWidget {
  const PrChecksPanel({super.key, required this.checks});

  final List<PrCheck> checks;

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
            color: TbColors.surface2,
            child: Text(
              'CHECKS',
              style: TbText.label(size: 11, weight: FontWeight.w600, color: TbColors.text, tracking: 1.0),
            ),
          ),
          if (checks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text('No checks reported.', style: TbText.body(size: 13, color: TbColors.muted)),
            )
          else
            for (int i = 0; i < checks.length; i++) _CheckRow(check: checks[i], isLast: i == checks.length - 1),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.isLast});

  final PrCheck check;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: TbColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            TbSignalDot(color: _dotColor(check.state), size: 7),
            const SizedBox(width: 8),
            Expanded(
              child: Text(check.name, style: TbText.label(size: 12, color: TbColors.text, tracking: 0.2)),
            ),
            if (check.summary != null)
              Text(check.summary!, style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.5)),
          ],
        ),
      ),
    );
  }
}

Color _dotColor(PrCheckState s) => switch (s) {
  PrCheckState.success => TbSignal.ok.border,
  PrCheckState.pending => TbSignal.warn.border,
  PrCheckState.failure => TbSignal.bad.border,
  PrCheckState.neutral => TbSignal.gray.border,
};
