// Test summary:
// - default interval is 5 minutes
// - ticks on the interval while resumed (invalidates remote providers, so
//   mounted listeners refetch)
// - pausing the app lifecycle (not `resumed`) stops the timer from ticking
// - returning to `resumed` fires an immediate catch-up tick and restarts the
//   periodic timer
// - stretches the interval to the realtime fallback (20m) while realtime is connected
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/presentation/providers/pr_inbox_provider.dart';
import 'package:turbo_board/features/realtime/presentation/providers/realtime_provider.dart';
import 'package:turbo_board/shared/ui/providers/auto_refresh_provider.dart';
import 'package:turbo_board/shared/ui/providers/refresh_interval_provider.dart';

void main() {
  // WidgetsBinding is required because AutoRefresh registers itself as a
  // WidgetsBindingObserver to gate the timer on app lifecycle.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Builds a container whose prInbox provider just counts how many times it is
  // (re)built — each auto-refresh tick invalidates it, so the count is our
  // proxy for "a tick fired and the mounted screen refetched".
  ({ProviderContainer container, int Function() builds}) makeContainer() {
    var builds = 0;
    final container = ProviderContainer(
      overrides: [
        prInboxProvider.overrideWith((ref) async {
          builds++;
          return <PrData>[];
        }),
      ],
    );
    // Keep prInbox alive so invalidation actually triggers a recompute
    // (invalidating an unlistened provider is a no-op).
    container.listen(prInboxProvider, (_, _) {});
    return (container: container, builds: () => builds);
  }

  AutoRefresh notifier(ProviderContainer c) => c.read(autoRefreshProvider.notifier);

  // Riverpod schedules recomputes on a macrotask, so flushMicrotasks isn't
  // enough — advance by 1ms (far below any refresh interval) to drain pending
  // rebuilds without firing the periodic timer.
  void settle(FakeAsync async) => async.elapse(const Duration(milliseconds: 1));

  test('default interval is 5 minutes', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(refreshIntervalProvider), refreshIntervalDefault);
  });

  test('ticks on the interval while resumed', () {
    fakeAsync((async) {
      final (:container, :builds) = makeContainer();
      addTearDown(container.dispose);

      notifier(container).didChangeAppLifecycleState(AppLifecycleState.resumed);
      settle(async);
      final base = builds();

      async.elapse(const Duration(seconds: refreshIntervalDefault));
      settle(async);
      expect(builds(), base + 1, reason: 'one tick after one interval');

      async.elapse(const Duration(seconds: refreshIntervalDefault));
      settle(async);
      expect(builds(), base + 2, reason: 'a second tick after another interval');
    });
  });

  test('does not tick while backgrounded / unfocused / tab hidden', () {
    fakeAsync((async) {
      final (:container, :builds) = makeContainer();
      addTearDown(container.dispose);

      notifier(container).didChangeAppLifecycleState(AppLifecycleState.resumed);
      settle(async);
      final base = builds();

      notifier(container).didChangeAppLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(seconds: refreshIntervalDefault * 4));
      settle(async);
      expect(builds(), base, reason: 'timer is cancelled while not resumed');
    });
  });

  test('resume fires an immediate catch-up tick and restarts the timer', () {
    fakeAsync((async) {
      final (:container, :builds) = makeContainer();
      addTearDown(container.dispose);

      notifier(container).didChangeAppLifecycleState(AppLifecycleState.paused);
      settle(async);
      final base = builds();

      notifier(container).didChangeAppLifecycleState(AppLifecycleState.resumed);
      settle(async);
      expect(builds(), base + 1, reason: 'immediate catch-up tick on resume');

      async.elapse(const Duration(seconds: refreshIntervalDefault));
      settle(async);
      expect(builds(), base + 2, reason: 'periodic timer resumed after catch-up');
    });
  });

  test('stretches the interval to the realtime fallback while connected', () {
    fakeAsync((async) {
      var builds = 0;
      final container = ProviderContainer(
        overrides: [
          realtimeListenerProvider.overrideWith(() => _StubListener(RealtimeStatus.connected)),
          prInboxProvider.overrideWith((ref) async {
            builds++;
            return <PrData>[];
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(prInboxProvider, (_, _) {});

      container.read(autoRefreshProvider.notifier).didChangeAppLifecycleState(AppLifecycleState.resumed);
      settle(async);
      final base = builds;

      // At the user default (5m) nothing should tick yet — we're stretched to 20m.
      async.elapse(const Duration(seconds: refreshIntervalDefault));
      settle(async);
      expect(builds, base, reason: 'no tick before the stretched interval');

      async.elapse(const Duration(seconds: realtimeFallbackInterval - refreshIntervalDefault));
      settle(async);
      expect(builds, base + 1, reason: 'one tick at the stretched 20m interval');
    });
  });
}

class _StubListener extends RealtimeListener {
  _StubListener(this._status);
  final RealtimeStatus _status;
  @override
  RealtimeStatus build() => _status;
}
