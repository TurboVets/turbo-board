// lib/features/projects_board/presentation/view/widgets/board_topbar.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../../lead_cockpit/presentation/view/widgets/project_picker.dart';
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
          Flexible(
            child: Text(
              board.title,
              overflow: TextOverflow.ellipsis,
              style: TbText.label(size: 14, weight: FontWeight.w600, tracking: 0.5),
            ),
          ),
          const SizedBox(width: 14),
          _pickerButton(context, ref),
          const Spacer(),
          _aiCta(ref, insights),
          const SizedBox(width: 10),
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

  Widget _pickerButton(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    icon: const Icon(LucideIcons.chevronDown, size: 13, color: TbColors.dim),
    label: Text('Switch board', style: TbText.label(size: 11, color: TbColors.muted, tracking: 0.3)),
    style: OutlinedButton.styleFrom(side: const BorderSide(color: TbColors.border)),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: TbColors.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ProjectPickerList(
            selectedKey: ref.read(selectedProjectProvider)?.key,
            onSelected: (p) {
              ref.read(selectedProjectProvider.notifier).select(p);
              ref.invalidate(projectsBoardProvider);
              ref.read(boardInsightsControllerProvider.notifier).clear();
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    ),
  );

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
