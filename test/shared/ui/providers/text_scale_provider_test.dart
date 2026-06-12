// Test summary:
// - default scale is 1.0
// - increase / decrease step by 0.1
// - clamps at textScaleMin and textScaleMax
// - reset returns to default
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/shared/ui/providers/text_scale_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });
  tearDown(() => container.dispose());

  double scale() => container.read(textScaleProvider);
  TextScaleNotifier notifier() => container.read(textScaleProvider.notifier);

  test('default is 1.0', () {
    expect(scale(), textScaleDefault);
  });

  test('increase / decrease step by 0.1', () {
    notifier().increase();
    expect(scale(), closeTo(1.1, 1e-9));
    notifier().decrease();
    expect(scale(), closeTo(1.0, 1e-9));
  });

  test('clamps at max', () {
    for (var i = 0; i < 20; i++) {
      notifier().increase();
    }
    expect(scale(), textScaleMax);
  });

  test('clamps at min', () {
    for (var i = 0; i < 20; i++) {
      notifier().decrease();
    }
    expect(scale(), textScaleMin);
  });

  test('reset returns to default', () {
    notifier().increase();
    notifier().increase();
    notifier().reset();
    expect(scale(), textScaleDefault);
  });

  test('setScale sets an absolute value (slider), clamped', () {
    notifier().setScale(18 / 14); // 18px via the Appearance slider
    expect(scale(), closeTo(1.3, 1e-9));
    notifier().setScale(99);
    expect(scale(), textScaleMax);
  });
}
