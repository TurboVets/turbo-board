// lib/features/projects_board/presentation/view/widgets/board_topbar.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../shared/ui/board/board_columns.dart';
import '../../../../../shared/ui/theme/tb_text.dart';
import 'board_assignee_filter.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../data/models/board_data.dart';
import '../../providers/projects_board_provider.dart';

/// Board topbar: title, project picker, inert group/filter affordances,
/// AI insights CTA, and a refresh button.
class BoardTopbar extends ConsumerWidget {
  const BoardTopbar({super.key, required this.board});

  final ProjectBoardData board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(boardInsightsControllerProvider);
    // True only while reloading on top of existing data (manual refresh or the
    // auto-refresh timer). Drives the refresh button's spinner.
    final boardAsync = ref.watch(projectsBoardProvider);
    final isRefreshing = boardAsync.isLoading && boardAsync.hasValue;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TbColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              board.title,
              overflow: TextOverflow.ellipsis,
              style: TbText.label(size: 14, weight: FontWeight.w600, tracking: 0.5),
            ),
          ),
          const SizedBox(width: 10),
          BoardAssigneeFilterButton(board: board),
          const SizedBox(width: 10),
          _aiCta(ref, insights),
          const SizedBox(width: 10),
          const BoardFitToggle(boardId: 'projects'),
          IconButton(
            tooltip: isRefreshing ? 'Refreshing…' : 'Refresh',
            icon: isRefreshing
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: TbColors.muted),
                  )
                : const Icon(LucideIcons.refreshCw, size: 15, color: TbColors.muted),
            onPressed: isRefreshing ? null : () => ref.invalidate(projectsBoardProvider),
          ),
          _preferencesButton(ref),
        ],
      ),
    );
  }

  Widget _preferencesButton(WidgetRef ref) {
    final hideEmpty = ref.watch(hideEmptyColumnsProvider);
    // Number of enabled preferences — drives the highlight + count badge, the
    // same affordance as the assignee filter button.
    final count = hideEmpty ? 1 : 0;
    final active = count > 0;
    return PopupMenuButton<String>(
      tooltip: 'Board preferences',
      padding: EdgeInsets.zero,
      color: TbColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: TbColors.border),
      ),
      onSelected: (value) {
        if (value == 'hideEmpty') ref.read(hideEmptyColumnsProvider.notifier).toggle();
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'hideEmpty',
          checked: hideEmpty,
          child: Text('Hide empty columns', style: TbText.body(size: 13, color: TbColors.text)),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: active ? TbColors.navy : Colors.transparent,
          border: Border.all(color: active ? TbColors.cyan : TbColors.borderStrong),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(LucideIcons.settings2, size: 15, color: active ? TbColors.cyan : TbColors.muted),
      ),
    );
  }

  Widget _aiCta(WidgetRef ref, AsyncValue<Map<IssueStatus, String>>? insights) {
    final loading = insights?.isLoading ?? false;
    final hasData = insights?.hasValue ?? false;
    final error = insights?.hasError ?? false;
    final label = error
        ? 'Retry insights'
        : hasData
        ? '↻ Regenerate'
        : '✨ AI Insights';
    return OutlinedButton(
      style: OutlinedButton.styleFrom(side: const BorderSide(color: TbColors.cyan)),
      onPressed: loading ? null : () => ref.read(boardInsightsControllerProvider.notifier).generate(board),
      child: loading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(
              label,
              style: TbText.label(size: 11, weight: FontWeight.w600, color: TbColors.cyan, tracking: 0.3),
            ),
    );
  }
}
