// Test summary:
// - maskSecret returns null for null/empty
// - short secrets are fully masked
// - long secrets keep a 7-char prefix and last 4
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/providers/ai_provider.dart';

void main() {
  test('null / empty → null', () {
    expect(maskSecret(null), isNull);
    expect(maskSecret(''), isNull);
  });

  test('short secret fully masked', () {
    expect(maskSecret('sk-ant-12'), '••••••••');
  });

  test('long secret keeps prefix and last 4', () {
    final masked = maskSecret('sk-ant-api03-ABCDEFGHIJ-WXYZ')!;
    expect(masked.startsWith('sk-ant-'), isTrue);
    expect(masked.endsWith('WXYZ'), isTrue);
    expect(masked.contains('••••••••'), isTrue);
    expect(masked.contains('ABCDEFGH'), isFalse);
  });
}
