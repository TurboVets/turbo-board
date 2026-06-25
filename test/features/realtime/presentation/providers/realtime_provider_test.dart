// Test summary:
// - backlog (fromInitialSnapshot) changes do NOT invalidate anything
// - a pull_request event invalidates the board (prInbox) after the debounce
// - a duplicate docId does not invalidate twice
// - issue_comment invalidates only the matching prDetail, not the board
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/pr_detail/presentation/providers/pr_detail_provider.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/presentation/providers/pr_inbox_provider.dart';
import 'package:turbo_board/features/realtime/data/models/repo_event.dart';
import 'package:turbo_board/features/realtime/data/repositories/realtime_repository.dart';
import 'package:turbo_board/features/realtime/presentation/providers/realtime_provider.dart';

RepoEventChange change(String event, {String repo = 'acme/web', int? pr, String id = 'd1', bool initial = false}) =>
    RepoEventChange(
      event: RepoEvent(repo: repo, event: event, prNumber: pr),
      docId: id,
      fromInitialSnapshot: initial,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'watched_repos': <String>['acme/web'],
    }),
  );

  ({ProviderContainer container, MockRealtimeRepository repo, int Function() board, int Function() detail42})
  makeContainer() {
    var board = 0;
    var detail42 = 0;
    final repo = MockRealtimeRepository();
    final container = ProviderContainer(
      overrides: [
        realtimeRepositoryProvider.overrideWithValue(repo),
        prInboxProvider.overrideWith((ref) async {
          board++;
          return <PrData>[];
        }),
        prDetailProvider(owner: 'acme', name: 'web', number: 42).overrideWith((ref) async {
          detail42++;
          throw UnimplementedError(); // value never read; we only count builds
        }),
      ],
    );
    // Keep targets alive so invalidation actually recomputes.
    container.listen(prInboxProvider, (_, _) {});
    container.listen(prDetailProvider(owner: 'acme', name: 'web', number: 42), (_, _) {});
    // Start the listener.
    container.listen(realtimeListenerProvider, (_, _) {});
    return (container: container, repo: repo, board: () => board, detail42: () => detail42);
  }

  void settle(FakeAsync a) => a.elapse(const Duration(milliseconds: 1));
  const debounce = Duration(seconds: 3);

  test('backlog changes do not invalidate', () {
    fakeAsync((async) {
      final c = makeContainer();
      addTearDown(c.container.dispose);
      settle(async);
      final base = c.board();
      c.repo.emit([change('pull_request', pr: 42, id: 'b1', initial: true)]);
      async.elapse(debounce);
      settle(async);
      expect(c.board(), base, reason: 'initial-snapshot backlog is suppressed');
    });
  });

  test('a pull_request event refetches the board after debounce', () {
    fakeAsync((async) {
      final c = makeContainer();
      addTearDown(c.container.dispose);
      settle(async);
      final base = c.board();
      c.repo.emit([change('pull_request', pr: 42, id: 'd1')]);
      async.elapse(debounce);
      settle(async);
      expect(c.board(), base + 1);
    });
  });

  test('a duplicate docId does not invalidate twice', () {
    fakeAsync((async) {
      final c = makeContainer();
      addTearDown(c.container.dispose);
      settle(async);
      c.repo.emit([change('pull_request', pr: 42, id: 'd1')]);
      async.elapse(debounce);
      settle(async);
      final after = c.board();
      c.repo.emit([change('pull_request', pr: 42, id: 'd1')]); // same id
      async.elapse(debounce);
      settle(async);
      expect(c.board(), after, reason: 'docId already handled this session');
    });
  });

  test('issue_comment invalidates only prDetail, not the board', () {
    fakeAsync((async) {
      final c = makeContainer();
      addTearDown(c.container.dispose);
      settle(async);
      final board0 = c.board();
      final detail0 = c.detail42();
      c.repo.emit([change('issue_comment', pr: 42, id: 'd9')]);
      async.elapse(debounce);
      settle(async);
      expect(c.board(), board0, reason: 'comments never touch the board');
      expect(c.detail42(), detail0 + 1, reason: 'the affected PR detail refetches');
    });
  });
}
