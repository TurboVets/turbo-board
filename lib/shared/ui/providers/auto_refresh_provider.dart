import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../features/lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../features/pr_detail/presentation/providers/pr_detail_provider.dart';
import '../../../features/pr_inbox/presentation/providers/pr_inbox_provider.dart';
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
@Riverpod(keepAlive: true)
class AutoRefresh extends _$AutoRefresh {
  Timer? _timer;

  @override
  void build() {
    final seconds = ref.watch(refreshIntervalProvider);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => _tick());
    ref.onDispose(() => _timer?.cancel());
  }

  void _tick() {
    ref.invalidate(prInboxProvider);
    ref.invalidate(leadCockpitProvider);
    ref.invalidate(sprintReportProvider);
    ref.invalidate(prDetailProvider);
  }
}
