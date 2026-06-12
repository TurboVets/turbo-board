// test/features/pr_inbox/presentation/view/widgets/pr_card_tap_test.dart
//
// Test summary:
// - tapping a PrCard with an onTap fires the callback.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_card.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

void main() {
  testWidgets('tap fires onTap', (tester) async {
    var tapped = false;
    final pr = PrData(
      repo: 'o/r',
      number: 1,
      title: 'PR',
      author: 'a',
      reviewState: PrReviewState.needsReview,
      ciState: PrCiState.passing,
      updatedAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: Scaffold(
          body: PrCard(pr: pr, onTap: () => tapped = true),
        ),
      ),
    );
    await tester.tap(find.byType(PrCard));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
