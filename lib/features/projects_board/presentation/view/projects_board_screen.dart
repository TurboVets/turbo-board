// lib/features/projects_board/presentation/view/projects_board_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/ui/theme/tb_breakpoints.dart';
import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../lead_cockpit/presentation/view/widgets/project_picker.dart';
import '../../data/models/board_data.dart';
import '../providers/projects_board_provider.dart';
import 'widgets/board_column.dart';
import 'widgets/board_topbar.dart';
import 'widgets/phone_column_selector.dart';

class ProjectsBoardScreen extends HookConsumerWidget {
  const ProjectsBoardScreen({super.key});

  static const String routeName = 'projectsBoard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProjectProvider);
    if (selected == null) return const _PickerEmptyState();

    final board = ref.watch(projectsBoardProvider);
    return board.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _ErrorState(message: '$err', onRetry: () => ref.invalidate(projectsBoardProvider)),
      data: (data) => _BoardBody(board: data),
    );
  }
}

class _BoardBody extends HookWidget {
  const _BoardBody({required this.board});
  final ProjectBoardData board;

  @override
  Widget build(BuildContext context) {
    final phoneIndex = useState(_defaultIndex(board));

    if (board.columns.isEmpty) {
      return const Center(child: Text('No columns'));
    }

    return Column(
      children: [
        BoardTopbar(board: board),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < TbBreakpoints.mobile) {
                final i = phoneIndex.value.clamp(0, board.columns.length - 1);
                return Column(
                  children: [
                    PhoneColumnSelector(
                      columns: board.columns,
                      selectedIndex: i,
                      onSelect: (n) => phoneIndex.value = n,
                    ),
                    Expanded(
                      child: BoardColumnView(
                        column: board.columns[i],
                        width: double.infinity,
                        onCardTap: (c) => _openCard(context, c),
                      ),
                    ),
                  ],
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < board.columns.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      SizedBox(
                        height: (constraints.maxHeight - 44).clamp(0, double.infinity),
                        child: BoardColumnView(
                          column: board.columns[i],
                          width: board.columns[i].status == IssueStatus.inProgress ? 272 : 236,
                          onCardTap: (c) => _openCard(context, c),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static int _defaultIndex(ProjectBoardData b) {
    final i = b.columns.indexWhere((c) => c.status == IssueStatus.inProgress);
    return i < 0 ? 0 : i;
  }

  void _openCard(BuildContext context, BoardCard card) {
    if (card.isPr && card.owner != null) {
      context.push('/pr/${card.owner}/${card.repo}/${card.number}');
    } else {
      _openOnGithub(card);
    }
  }
}

/// Empty state shown when no project has been selected yet.
/// Must be a ConsumerWidget so it can call [selectedProjectProvider.notifier.select].
class _PickerEmptyState extends ConsumerWidget {
  const _PickerEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Pick a project board', style: TbText.label(size: 14, weight: FontWeight.w600, tracking: 0.5)),
          const SizedBox(height: 6),
          Text(
            'Choose a GitHub ProjectV2 board to view as a kanban board.',
            textAlign: TextAlign.center,
            style: TbText.body(size: 13, color: TbColors.muted),
          ),
          const SizedBox(height: 16),
          ProjectPickerList(onSelected: (p) => ref.read(selectedProjectProvider.notifier).select(p)),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TbText.body(size: 13, color: TbColors.muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: Text('Retry', style: TbText.label(size: 12, tracking: 0.3)),
          ),
        ],
      ),
    ),
  );
}

/// Opens a board card's URL on GitHub. For issues it builds the URL from the
/// card's owner/repo/number. For PRs this helper is not used (routed in-app).
/// Mirrors [StuckIssueRow]'s `launchUrl` + [LaunchMode.externalApplication].
void _openOnGithub(BoardCard card) {
  final owner = card.owner;
  if (owner == null) return;
  final type = card.isPr ? 'pull' : 'issues';
  final url = 'https://github.com/$owner/${card.repo}/$type/${card.number}';
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
