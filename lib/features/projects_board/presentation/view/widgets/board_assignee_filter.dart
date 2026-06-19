// lib/features/projects_board/presentation/view/widgets/board_assignee_filter.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/board_data.dart';
import '../../providers/projects_board_provider.dart';

/// Topbar control that filters the board by assignee (multi-select), including
/// an "Unassigned" option. Empty selection shows everything.
class BoardAssigneeFilterButton extends ConsumerWidget {
  const BoardAssigneeFilterButton({super.key, required this.board});

  final ProjectBoardData board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(boardAssigneeFilterProvider);
    final notifier = ref.read(boardAssigneeFilterProvider.notifier);
    final assignees = boardAssignees(board);
    final active = selected.isNotEmpty;

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(TbColors.surface),
        side: const WidgetStatePropertyAll(BorderSide(color: TbColors.border)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
      menuChildren: [
        _row(
          selected: selected.contains(kBoardUnassigned),
          onTap: () => notifier.toggle(kBoardUnassigned),
          leading: const Icon(Icons.person_off_outlined, size: 16, color: TbColors.muted),
          label: 'Unassigned',
        ),
        if (assignees.isNotEmpty) const Divider(height: 1, color: TbColors.border),
        for (final login in assignees)
          _row(
            selected: selected.contains(login),
            onTap: () => notifier.toggle(login),
            leading: TbAvatarTile(login: login, size: 18),
            label: login,
          ),
        if (active) ...[
          const Divider(height: 1, color: TbColors.border),
          MenuItemButton(
            closeOnActivate: false,
            onPressed: notifier.clear,
            child: Text('Clear filter', style: TbText.label(size: 12, color: TbColors.cyan, tracking: 0.3)),
          ),
        ],
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: Icon(Icons.people_alt_outlined, size: 15, color: active ? TbColors.cyan : TbColors.muted),
        label: Text(
          active ? 'Assignee · ${selected.length}' : 'Assignee',
          style: TbText.label(size: 12, color: active ? TbColors.cyan : TbColors.text, tracking: 0.3),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: active ? TbColors.cyan : TbColors.borderStrong),
          backgroundColor: active ? TbColors.navy : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

  Widget _row({required bool selected, required VoidCallback onTap, required Widget leading, required String label}) {
    return MenuItemButton(
      closeOnActivate: false,
      onPressed: onTap,
      leadingIcon: Icon(
        selected ? Icons.check_box : Icons.check_box_outline_blank,
        size: 16,
        color: selected ? TbColors.cyan : TbColors.dim,
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 8),
            Text(label, style: TbText.body(size: 13, color: TbColors.text)),
          ],
        ),
      ),
    );
  }
}
