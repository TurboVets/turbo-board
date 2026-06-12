// lib/features/pr_detail/presentation/providers/pr_composer_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../pr_inbox/presentation/providers/pr_inbox_provider.dart';
import '../../data/models/pr_detail.dart';
import 'pr_detail_provider.dart';

part 'pr_composer_provider.g.dart';

/// Drives the PR detail comment composer: posting a comment, approving, or
/// requesting changes. State is `null` when idle, [AsyncLoading] while a
/// request is in flight, [AsyncData] on success, [AsyncError] on failure.
///
/// On success the matching [prDetailProvider] is invalidated so the freshly
/// posted comment / review shows up in the timeline.
@riverpod
class PrComposer extends _$PrComposer {
  @override
  AsyncValue<void>? build({required String owner, required String name, required int number}) => null;

  Future<bool> _run(Future<Result<bool>> Function() op) async {
    state = const AsyncLoading();
    final res = await op();
    switch (res) {
      case ResultSuccess():
        state = const AsyncData(null);
        // Reload the detail (new comment / updated review state) and the board /
        // needs-attention views, which derive from the inbox, so the PR's status
        // and column placement refresh everywhere.
        ref.invalidate(prDetailProvider(owner: owner, name: name, number: number));
        ref.invalidate(prInboxProvider);
        return true;
      case ResultFailure(:final message):
        state = AsyncError(message, StackTrace.current);
        return false;
    }
  }

  /// Posts [body] as a comment on the PR conversation. [prId] is the PR node id.
  Future<bool> comment(String prId, String body) =>
      _run(() => ref.read(prDetailRepositoryProvider).addComment(prId, body));

  Future<bool> approve(String prId, String body) =>
      _run(() => ref.read(prDetailRepositoryProvider).submitReview(prId, 'APPROVE', body));

  Future<bool> requestChanges(String prId, String body) =>
      _run(() => ref.read(prDetailRepositoryProvider).submitReview(prId, 'REQUEST_CHANGES', body));

  /// Merges the PR with the chosen [method]. On success the detail and inbox
  /// reload, so the PR flips to merged everywhere.
  Future<bool> merge(String prId, PrMergeMethod method) =>
      _run(() => ref.read(prDetailRepositoryProvider).mergePullRequest(prId, method.graphql));

  /// Deletes the PR's head branch. [refId] is the head ref node id. On success
  /// the detail reloads; `headRef` is then null, hiding the action.
  Future<bool> deleteBranch(String refId) => _run(() => ref.read(prDetailRepositoryProvider).deleteHeadBranch(refId));
}
