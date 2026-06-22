import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../features/lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../features/pr_detail/presentation/providers/pr_detail_provider.dart';
import '../../../features/pr_inbox/presentation/providers/pr_inbox_provider.dart';
import '../../../features/projects_board/presentation/providers/projects_board_provider.dart';
import '../../../features/sprint_report/presentation/providers/sprint_report_provider.dart';
import 'refresh_interval_provider.dart';

part 'auto_refresh_provider.g.dart';

/// Drives app-wide periodic data refresh. Watches the user's chosen interval
/// and, on each tick, invalidates every remote data provider so the visible
/// screen refetches live GitHub data. Kept alive at the app root (watched in
/// `TurboBoardApp`); rebuilding when the interval changes restarts the timer.
///
/// Invalidating a provider with no active listeners is a no-op, so only the
/// mounted screen actually refetches. `prDetailProvider` is a family —
/// invalidating it clears every cached (owner, name, number) instance.
///
/// The timer is gated by app lifecycle: it only ticks while the app is
/// `resumed` (foreground window / focused, visible browser tab). When the app
/// is backgrounded, loses focus, or the tab is hidden the timer is paused so we
/// don't hammer the GitHub API for a view nobody is looking at. On resume we
/// fire one immediate catch-up tick and restart the timer. Flutter maps web tab
/// `visibilitychange`/`focus` events to `AppLifecycleState`, so this single
/// path covers desktop, mobile, and web with no platform-specific code.
@Riverpod(keepAlive: true)
class AutoRefresh extends _$AutoRefresh with WidgetsBindingObserver {
  Timer? _timer;
  int _seconds = refreshIntervalDefault;

  @override
  void build() {
    _seconds = ref.watch(refreshIntervalProvider);
    WidgetsBinding.instance.addObserver(this);
    // Only run the timer if we're currently in the foreground. On first build
    // lifecycleState may be null (pre-first-frame) — treat that as resumed.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      _start();
    }
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: _seconds), (_) => _tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick(); // catch up on whatever we missed while away
      _start();
    } else {
      _timer?.cancel(); // pause while backgrounded / unfocused / tab hidden
    }
  }

  void _tick() {
    ref.invalidate(prInboxProvider);
    ref.invalidate(leadCockpitProvider);
    ref.invalidate(sprintReportProvider);
    ref.invalidate(prDetailProvider);
    ref.invalidate(projectsBoardProvider);
  }
}
