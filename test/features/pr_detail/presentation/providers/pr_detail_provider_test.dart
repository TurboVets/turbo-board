// test/features/pr_detail/presentation/providers/pr_detail_provider_test.dart
//
// Test summary:
// - prDetail returns the repo's PrDetail on success.
// - prDetail throws when the repo fails.
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';
import 'package:turbo_board/features/pr_detail/data/repositories/pr_detail_repository.dart';
import 'package:turbo_board/features/pr_detail/presentation/providers/pr_detail_provider.dart';
import 'package:turbo_core/core.dart';

class _Repo implements PrDetailRepository {
  _Repo({this.fail = false});
  final bool fail;
  @override
  Future<Result<PrDetail>> fetchDetail(String owner, String name, int number) async => fail
      ? Result.failure('boom', StackTrace.current)
      : Result.success(
          PrDetail(
            repo: '$owner/$name',
            number: number,
            title: 't',
            state: PrState.open,
            author: 'a',
            baseRefName: 'main',
            headRefName: 'f',
          ),
        );

  @override
  Future<Result<bool>> addComment(String subjectId, String body) async => Result.success(true);

  @override
  Future<Result<bool>> submitReview(String pullRequestId, String event, String body) async => Result.success(true);

  @override
  Future<Result<bool>> mergePullRequest(String pullRequestId, String mergeMethod) async => Result.success(true);
}

void main() {
  test('returns detail on success', () async {
    final c = ProviderContainer(overrides: [prDetailRepositoryProvider.overrideWithValue(_Repo())]);
    addTearDown(c.dispose);
    final d = await c.read(prDetailProvider(owner: 'o', name: 'r', number: 5).future);
    expect(d.slug, 'o/r#5');
  });

  test('throws on failure', () async {
    final c = ProviderContainer(overrides: [prDetailRepositoryProvider.overrideWithValue(_Repo(fail: true))]);
    addTearDown(c.dispose);
    final sub = c.listen(prDetailProvider(owner: 'o', name: 'r', number: 1), (_, _) {}, fireImmediately: true);
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().hasError, isTrue);
  });
}
