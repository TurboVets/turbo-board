import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'refresh_interval_provider.g.dart';

const _prefsKey = 'refresh_interval_seconds';

/// Discrete auto-refresh interval steps, in seconds — 30s … 1h. The settings
/// slider snaps to these so users pick sensible cadences instead of arbitrary
/// per-second values.
const List<int> refreshIntervalSteps = [30, 60, 120, 300, 600, 900, 1800, 3600];

/// Default cadence on first run — 5 minutes.
const int refreshIntervalDefault = 300;

/// Compact label for a step (e.g. `30S`, `5M`, `1H`) shown next to the slider.
String refreshIntervalLabel(int seconds) {
  if (seconds < 60) return '${seconds}S';
  if (seconds < 3600) return '${seconds ~/ 60}M';
  return '${seconds ~/ 3600}H';
}

/// App-wide auto-refresh interval (seconds), persisted to shared_preferences.
/// Consumed by [AutoRefresh] to drive the periodic provider invalidation.
@Riverpod(keepAlive: true)
class RefreshIntervalNotifier extends _$RefreshIntervalNotifier {
  @override
  int build() {
    load(); // hydrate from shared_preferences on first build
    return refreshIntervalDefault;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_prefsKey);
    if (stored != null) state = stored.clamp(refreshIntervalSteps.first, refreshIntervalSteps.last);
  }

  void setSeconds(int seconds) => _set(seconds);

  Future<void> _set(int value) async {
    final clamped = value.clamp(refreshIntervalSteps.first, refreshIntervalSteps.last);
    if (clamped == state) return;
    state = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, clamped);
  }
}
