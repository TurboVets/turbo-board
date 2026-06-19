import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../ai/presentation/providers/ai_provider.dart';
import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../data/models/board_data.dart';
import '../../data/repositories/projects_board_repository.dart';

part 'projects_board_provider.g.dart';

@Riverpod(keepAlive: true)
ProjectsBoardRepository projectsBoardRepository(Ref ref) {
  final client = ref.watch(githubApiClientProvider);
  final selected = ref.watch(selectedProjectProvider);
  return GithubProjectsBoardRepository(client, org: selected?.owner ?? '', projectNumber: selected?.number ?? 0);
}

@riverpod
Future<ProjectBoardData> projectsBoard(Ref ref) async {
  final result = await ref.watch(projectsBoardRepositoryProvider).fetchBoard();
  return result.when(
    success: (data) {
      if (ref.mounted) ref.keepAlive();
      return data;
    },
    failure: (message, _) => throw Exception(message),
  );
}

/// Which sprint filter tab the board is showing. Defaults to the current
/// sprint, per the design — the board opens on the in-flight iteration. Resets
/// to current when the screen is rebuilt (auto-dispose) so a fresh visit always
/// lands on "now".
@riverpod
class SelectedSprintTab extends _$SelectedSprintTab {
  @override
  SprintTab build() => SprintTab.current;

  void select(SprintTab tab) => state = tab;
}

/// On-demand AI column insights. `null` = not requested yet (mirrors the cockpit
/// brief / PR summary controllers). Never auto-fires.
@riverpod
class BoardInsightsController extends _$BoardInsightsController {
  @override
  AsyncValue<Map<IssueStatus, String>>? build() => null;

  Future<void> generate(ProjectBoardData board) async {
    state = const AsyncValue.loading();
    final result = await ref.read(aiRepositoryProvider).boardInsights(board);
    state = switch (result) {
      ResultSuccess(:final data) => AsyncValue.data(data),
      ResultFailure(:final message) => AsyncValue.error(message, StackTrace.current),
    };
  }

  void clear() => state = null;
}

/// Sentinel member of the assignee filter meaning "no assignee".
const String kBoardUnassigned = '(unassigned)';

/// Selected assignee logins to filter the board by (plus [kBoardUnassigned] for
/// unowned cards). Empty = no filter (show everything). Session-scoped.
@Riverpod(keepAlive: true)
class BoardAssigneeFilter extends _$BoardAssigneeFilter {
  @override
  Set<String> build() => const {};

  void toggle(String key) {
    final next = {...state};
    next.contains(key) ? next.remove(key) : next.add(key);
    state = next;
  }

  void clear() => state = const {};
}

/// All assignee logins present on the board, deduped and sorted.
List<String> boardAssignees(ProjectBoardData board) {
  final logins = <String>{};
  for (final col in board.columns) {
    for (final card in col.cards) {
      logins.addAll(card.assignees);
    }
  }
  final sorted = logins.toList()..sort();
  return sorted;
}

/// Filters [board]'s cards by [filter]. Empty filter returns [board] unchanged.
/// A card matches if any of its assignees is selected, or — when
/// [kBoardUnassigned] is selected — it has no assignees.
ProjectBoardData filterBoardByAssignees(ProjectBoardData board, Set<String> filter) {
  if (filter.isEmpty) return board;
  bool matches(BoardCard c) {
    if (c.assignees.isEmpty) return filter.contains(kBoardUnassigned);
    return c.assignees.any(filter.contains);
  }

  return board.copyWith(
    columns: [for (final col in board.columns) col.copyWith(cards: col.cards.where(matches).toList())],
  );
}
