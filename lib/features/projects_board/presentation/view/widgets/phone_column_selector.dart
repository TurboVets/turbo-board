import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../data/models/board_data.dart';
import '../../helpers/board_palette.dart';

/// Horizontal status pills shown on phone widths; one per column.
class PhoneColumnSelector extends StatelessWidget {
  const PhoneColumnSelector({super.key, required this.columns, required this.selectedIndex, required this.onSelect});

  final List<BoardColumn> columns;
  final int selectedIndex;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _pill(columns[i], i == selectedIndex, () => onSelect(i)),
        ],
      ],
    ),
  );

  Widget _pill(BoardColumn col, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: active ? TbColors.navy : TbColors.surface,
        border: Border.all(color: active ? TbColors.cyan : TbColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, color: BoardPalette.columnAccent(col.status)),
          const SizedBox(width: 7),
          Text(
            '${col.label} · ${col.count}',
            style: TbText.label(
              size: 11,
              weight: FontWeight.w600,
              tracking: 0.3,
              color: active ? const Color(0xFFB2EBFF) : TbColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}
