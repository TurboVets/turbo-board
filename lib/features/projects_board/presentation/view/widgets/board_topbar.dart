// lib/features/projects_board/presentation/view/widgets/board_topbar.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../shared/ui/board/board_columns.dart';
import '../../../../../shared/ui/theme/tb_text.dart';
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
        ],
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
