// lib/features/projects_board/presentation/view/widgets/board_card.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../../lead_cockpit/presentation/helpers/cockpit_palette.dart';
import '../../../data/models/board_data.dart';
import '../../helpers/board_palette.dart';

/// A single board card (issue or PR), matching `Projects Board.dc.html`.
class BoardCardTile extends StatelessWidget {
  const BoardCardTile({super.key, required this.card, required this.onTap});

  final BoardCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Tint the border with the (first) assignee's avatar color so a card reads
    // as "theirs" at a glance; fall back to the P0 / default border when unowned.
    final assigned = card.assignees.isNotEmpty;
    final borderColor = assigned
        ? TbAvatar.bgFor(card.assignees.first)
        : (card.priority == IssuePriority.p0 ? const Color(0xFF5E2230) : TbColors.border);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TbColors.surface2,
            border: Border.all(color: borderColor, width: assigned ? 1.5 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topRow(),
              const SizedBox(height: 8),
              _title(),
              const SizedBox(height: 11),
              _metaRow(),
              const SizedBox(height: 11),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topRow() => Row(
    children: [
      TbSignalDot(color: TbRepoColor.forSlug(card.repo), size: 7),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          card.repo,
          overflow: TextOverflow.ellipsis,
          style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.2),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        '#${card.number}',
        style: TbText.label(size: 10, weight: FontWeight.w600, color: TbColors.dim),
      ),
    ],
  );

  Widget _title() => Text.rich(
    TextSpan(
      children: [
        if (card.isDraft)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TbBadge('Draft', TbSignal.gray, small: true),
            ),
          ),
        TextSpan(
          text: card.title,
          style: TbText.body(size: 13, weight: FontWeight.w600, color: TbColors.text, height: 1.4),
        ),
      ],
    ),
    softWrap: true,
  );

  Widget _metaRow() => Wrap(
    spacing: 6,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (card.priority != null)
        TbBadge(
          CockpitPalette.priorityLabel(card.priority!),
          CockpitPalette.prioritySignal(card.priority!),
          small: true,
          tooltip: CockpitPalette.priorityTooltip(card.priority!),
        ),
      if (card.points != null) TbBadge('${card.points} SP', TbSignal.gray, small: true),
      if (card.hasSubIssues) _subProgress(),
      if (card.isStale) TbBadge('⏱ ${card.staleDays}d', TbSignal.orange, small: true),
    ],
  );

  Widget _subProgress() {
    final pct = (card.subTotal ?? 0) == 0 ? 0.0 : (card.subDone ?? 0) / card.subTotal!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: TbColors.canvas,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF54AE39)),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text('${card.subDone}/${card.subTotal}', style: TbText.label(size: 10, color: TbColors.muted, tracking: 0.2)),
      ],
    );
  }

  Widget _footer() => Row(
    children: [
      // Leading CI/REV signals take the remaining width and clip when a column
      // is squeezed narrow (fit-to-width mode), so the row never overflows.
      if (card.isPr)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                _signalLabel('CI', BoardPalette.ciDot(card.ciState ?? PrCiState.none)),
                const SizedBox(width: 11),
                _signalLabel('REV', BoardPalette.reviewDot(card.reviewState ?? PrReviewState.none)),
              ],
            ),
          ),
        )
      else
        const Spacer(),
      _assignees(),
    ],
  );

  Widget _signalLabel(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.3)),
    ],
  );

  Widget _assignees() {
    if (card.assignees.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < card.assignees.length; i++)
          Transform.translate(
            offset: Offset(i == 0 ? 0 : -6.0 * i, 0),
            child: TbAvatarTile(login: card.assignees[i], size: 21),
          ),
      ],
    );
  }
}
