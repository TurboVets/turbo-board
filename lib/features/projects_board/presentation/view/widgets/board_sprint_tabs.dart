// lib/features/projects_board/presentation/view/widgets/board_sprint_tabs.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../data/models/board_data.dart';
import '../../../data/repositories/board_mapper.dart';
import '../../providers/projects_board_provider.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// GitHub-style sprint filter tabs above the board: Current / Previous / Next
/// sprint and All Tasks. Relative tabs render only when the catalog has a
/// neighbouring iteration. Hidden entirely when the board has no Sprint field.
class BoardSprintTabs extends ConsumerWidget {
  const BoardSprintTabs({super.key, required this.board});

  final ProjectBoardData board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sprints = board.sprints;
    if (sprints.isEmpty) return const SizedBox.shrink();

    final selected = ref.watch(selectedSprintTabProvider);
    final tabs = _visibleTabs(sprints);
    // Highlight the selected tab; if it resolved away (e.g. no current sprint),
    // fall back to All so something always reads as active.
    final effective = tabs.any((t) => t.tab == selected) ? selected : SprintTab.all;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TbColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final t in tabs)
              _Tab(
                label: t.label,
                sub: t.sub,
                active: t.tab == effective,
                onTap: () => ref.read(selectedSprintTabProvider.notifier).select(t.tab),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the ordered tab list: Current / Previous / Next (each only when a
  /// matching iteration exists) followed by the always-present All Tasks tab.
  List<_TabSpec> _visibleTabs(List<BoardSprint> sprints) {
    final specs = <_TabSpec>[];
    for (final entry in const [
      (SprintTab.current, 'Current Sprint'),
      (SprintTab.previous, 'Previous Sprint'),
      (SprintTab.next, 'Next Sprint'),
    ]) {
      final title = sprintTitleForTab(sprints, entry.$1);
      if (title == null) continue;
      final sprint = sprints.firstWhere((s) => s.title == title);
      specs.add(_TabSpec(entry.$1, entry.$2, '${sprint.title} · ${_range(sprint)}'));
    }
    specs.add(const _TabSpec(SprintTab.all, 'All Tasks', 'Every item in the project'));
    return specs;
  }

  String _range(BoardSprint s) {
    final start = s.start;
    final end = s.end.subtract(const Duration(days: 1)); // inclusive last day
    final left = '${_months[start.month - 1]} ${start.day}';
    final right = start.month == end.month ? '${end.day}' : '${_months[end.month - 1]} ${end.day}';
    return '$left – $right';
  }
}

class _TabSpec {
  const _TabSpec(this.tab, this.label, this.sub);
  final SprintTab tab;
  final String label;
  final String sub;
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.sub, required this.active, required this.onTap});

  final String label;
  final String sub;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? TbColors.text : TbColors.muted;
    return Tooltip(
      message: sub,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? TbColors.cyan : Colors.transparent, width: 2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.columns3, size: 14, color: active ? TbColors.cyan : TbColors.dim),
              const SizedBox(width: 8),
              Text(
                label,
                style: TbText.label(size: 13, weight: active ? FontWeight.w600 : FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
