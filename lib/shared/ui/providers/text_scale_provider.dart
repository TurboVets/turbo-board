import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'text_scale_provider.g.dart';

const _prefsKey = 'text_scale';
const double textScaleMin = 0.8;
const double textScaleMax = 1.6;
const double _step = 0.1;
const double textScaleDefault = 1.0;

/// App-wide text scale factor, adjustable via Cmd/Ctrl +/-/0 and persisted to
/// shared_preferences. Applied at the root via `MediaQuery.textScaler`.
@Riverpod(keepAlive: true)
class TextScaleNotifier extends _$TextScaleNotifier {
  @override
  double build() {
    load(); // hydrate from shared_preferences on first build
    return textScaleDefault;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_prefsKey);
    if (stored != null) state = stored.clamp(textScaleMin, textScaleMax);
  }

  void increase() => _set(state + _step);

  void decrease() => _set(state - _step);

  void reset() => _set(textScaleDefault);

  /// Sets an absolute scale (used by the Appearance slider). Clamped + persisted.
  void setScale(double scale) => _set(scale);

  Future<void> _set(double value) async {
    // Round to one decimal to avoid float drift across many steps.
    final clamped = value.clamp(textScaleMin, textScaleMax);
    final next = double.parse(clamped.toStringAsFixed(1));
    if (next == state) return;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, next);
  }
}
