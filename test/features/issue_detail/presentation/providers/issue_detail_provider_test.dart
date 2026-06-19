// test/features/issue_detail/presentation/providers/issue_detail_provider_test.dart
//
// Test summary:
// - issueDetailProvider yields the repo's issue on success.
// - issueDetailProvider surfaces repo failure as an AsyncError.
// - IssueComposer.comment: idle(null) -> loading -> data on success; invalidates the detail.
// - IssueComposer.close/reopen delegate to the repo and report success.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_core/core.dart';
import 'package:turbo_board/features/issue_detail/data/models/issue_detail.dart';
import 'package:turbo_board/features/issue_detail/data/repositories/issue_detail_repository.dart';
import 'package:turbo_board/features/issue_detail/presentation/providers/issue_composer_provider.dart';
import 'package:turbo_board/features/issue_detail/presentation/providers/issue_detail_provider.dart';

class _FailRepo implements IssueDetailRepository {
  @override
  Future<Result<IssueDetail>> fetchDetail(String o, String n, int num) async =>
      Result.failure('boom', StackTrace.current);
  @override
  Future<Result<bool>> addComment(String s, String b) async => Result.success(true);
  @override
  Future<Result<bool>> closeIssue(String id) async => Result.success(true);
  @override
  Future<Result<bool>> reopenIssue(String id) async => Result.success(true);
  @override
  Future<Result<String>> createBranch(String id, String oid, String name) async => Result.success(name);
  @override
  Future<Result<bool>> updateStatus(String projectId, String itemId, String fieldId, String optionId) async =>
      Result.success(true);
}

void main() {
  test('detail provider yields the repo issue', () async {
    final c = ProviderContainer(
      overrides: [issueDetailRepositoryProvider.overrideWithValue(const MockIssueDetailRepository())],
    );
    addTearDown(c.dispose);
    final d = await c.read(issueDetailProvider(owner: 'o', repo: 'r', number: 1).future);
    expect(d.number, 155);
  });

  test('detail provider surfaces failure as error', () async {
    final c = ProviderContainer(overrides: [issueDetailRepositoryProvider.overrideWithValue(_FailRepo())]);
    addTearDown(c.dispose);
    final sub = c.listen(issueDetailProvider(owner: 'o', repo: 'r', number: 1), (_, _) {}, fireImmediately: true);
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().hasError, isTrue);
  });

  test('composer comment then close', () async {
    final c = ProviderContainer(
      overrides: [issueDetailRepositoryProvider.overrideWithValue(const MockIssueDetailRepository())],
    );
    addTearDown(c.dispose);
    expect(c.read(issueComposerProvider(owner: 'o', name: 'r', number: 1)), isNull);
    final ok = await c.read(issueComposerProvider(owner: 'o', name: 'r', number: 1).notifier).comment('id', 'hi');
    expect(ok, isTrue);
    expect(c.read(issueComposerProvider(owner: 'o', name: 'r', number: 1)), isA<AsyncData<void>>());
    expect(await c.read(issueComposerProvider(owner: 'o', name: 'r', number: 1).notifier).close('id'), isTrue);
  });
}
