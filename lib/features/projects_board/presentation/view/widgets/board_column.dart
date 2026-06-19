// lib/features/projects_board/presentation/view/widgets/board_column.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../data/models/board_data.dart';
import '../../helpers/board_palette.dart';
import '../../providers/projects_board_provider.dart';
import 'board_card.dart';

/// One Status column: accent header, optional AI insight line, scrollable cards.
class BoardColumnView extends ConsumerWidget {
  const BoardColumnView({super.key, required this.column, required this.onCardTap, this.width});

  final BoardColumn column;
  final void Function(BoardCard) onCardTap;

  /// Fixed column width. `null` fills the parent's constraints (used in
  /// fit-to-width mode where the column sits inside an [Expanded]).
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(boardInsightsControllerProvider);
    final accent = BoardPalette.columnAccent(column.status);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border(top: BorderSide(color: accent, width: 2)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(accent),
          if (insights != null) _insightRow(insights),
          Expanded(child: _cards()),
        ],
      ),
    );
  }

  Widget _header(Color accent) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
    child: Row(
      children: [
        TbSignalDot(color: accent, size: 7),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            column.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TbText.label(size: 11, weight: FontWeight.w600, tracking: 0.4),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: TbColors.surface2,
            border: Border.all(color: TbColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${column.count}',
            style: TbText.label(size: 10, weight: FontWeight.w600, color: TbColors.muted),
          ),
        ),
      ],
    ),
  );

  Widget _insightRow(AsyncValue<Map<IssueStatus, String>> insights) => insights.when(
    loading: () => _insightShell(const _Shimmer()),
    error: (_, _) => const SizedBox.shrink(),
    data: (map) {
      final line = map[column.status];
      if (line == null) return const SizedBox.shrink();
      return _insightShell(Text(line, style: TbText.body(size: 11, color: TbColors.muted, height: 1.4)));
    },
  );

  Widget _insightShell(Widget child) => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
    decoration: BoxDecoration(
      color: TbColors.canvas,
      border: Border.all(color: TbColors.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 2, height: 16, color: TbColors.cyan),
        const SizedBox(width: 7),
        const TbBadge('AI', TbSignal.info, small: true),
        const SizedBox(width: 7),
        Expanded(child: child),
      ],
    ),
  );

  Widget _cards() {
    if (column.cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: TbColors.border, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text('No items', style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.5)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
      itemCount: column.cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => BoardCardTile(card: column.cards[i], onTap: () => onCardTap(column.cards[i])),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();
  @override
  Widget build(BuildContext context) => Container(
    height: 11,
    decoration: BoxDecoration(color: TbColors.surface2, borderRadius: BorderRadius.circular(2)),
  );
}
