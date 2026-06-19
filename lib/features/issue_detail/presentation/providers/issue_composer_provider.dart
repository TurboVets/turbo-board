// lib/features/issue_detail/presentation/providers/issue_composer_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../projects_board/presentation/providers/projects_board_provider.dart';
import 'issue_detail_provider.dart';

part 'issue_composer_provider.g.dart';

/// Drives the issue comment composer + close/reopen + create-branch. State is
/// `null` when idle, [AsyncLoading] in flight, [AsyncData] on success,
/// [AsyncError] on failure. On success the matching [issueDetailProvider] is
/// invalidated so the timeline / state refreshes.
@riverpod
class IssueComposer extends _$IssueComposer {
  @override
  AsyncValue<void>? build({required String owner, required String name, required int number}) => null;

  Future<bool> _run<T>(Future<Result<T>> Function() op) async {
    state = const AsyncLoading();
    final res = await op();
    switch (res) {
      case ResultSuccess():
        state = const AsyncData(null);
        ref.invalidate(issueDetailProvider(owner: owner, repo: name, number: number));
        // Issue changes (status / close / reopen) move cards between columns, so
        // refresh the board view too.
        ref.invalidate(projectsBoardProvider);
        return true;
      case ResultFailure(:final message):
        state = AsyncError(message, StackTrace.current);
        return false;
    }
  }

  Future<bool> comment(String issueId, String body) =>
      _run(() => ref.read(issueDetailRepositoryProvider).addComment(issueId, body));

  Future<bool> close(String issueId) => _run(() => ref.read(issueDetailRepositoryProvider).closeIssue(issueId));

  Future<bool> reopen(String issueId) => _run(() => ref.read(issueDetailRepositoryProvider).reopenIssue(issueId));

  Future<bool> createBranch(String issueId, String oid, String branchName) =>
      _run(() => ref.read(issueDetailRepositoryProvider).createBranch(issueId, oid, branchName));

  Future<bool> setStatus(String projectId, String itemId, String fieldId, String optionId) =>
      _run(() => ref.read(issueDetailRepositoryProvider).updateStatus(projectId, itemId, fieldId, optionId));
}
