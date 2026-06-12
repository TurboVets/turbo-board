// lib/features/pr_inbox/presentation/view/widgets/pr_column.dart
import 'package:flutter/material.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../data/models/pr_data.dart';
import 'pr_card.dart';

/// One board column: a header (title + count) over a scrollable list of [PrCard]s.
///
/// Fills the height it is given (it uses [Expanded] internally), so the parent
/// MUST constrain its height — the board wraps each column in a height-bounded
/// `SizedBox` (see [_Board]). In tests, a `Scaffold` body provides that bound.
class PrColumn extends StatelessWidget {
  const PrColumn({super.key, required this.title, required this.prs, this.onCardTap});

  final String title;
  final List<PrData> prs;
  final void Function(PrData pr)? onCardTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            children: [
              Text(title, style: text.titleSmall),
              const SizedBox(width: 8),
              Text('${prs.length}', style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted)),
            ],
          ),
        ),
        Expanded(
          child: prs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('None', style: text.bodySmall?.copyWith(color: colors.foreground.primaryMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: prs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      PrCard(pr: prs[i], onTap: onCardTap == null ? null : () => onCardTap!(prs[i])),
                ),
        ),
      ],
    );
  }
}
