// test/features/pr_inbox/presentation/view/widgets/pr_column_test.dart
//
// Test summary:
// - shows the column title and the item count.
// - renders one PrCard per item; shows "None" when empty.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_card.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_column.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

PrData _pr(int n) => PrData(
  repo: 'o/r',
  number: n,
  title: 'PR $n',
  author: 'a',
  reviewState: PrReviewState.needsReview,
  ciState: PrCiState.passing,
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  testWidgets('shows title, count and a card per item', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: Scaffold(
          body: PrColumn(title: 'Needs review', prs: [_pr(1), _pr(2)]),
        ),
      ),
    );

    // "Needs review" also appears in each PrCard's review badge; check at least one
    // (the header) is present. findsOneWidget would false-fail due to badge collisions.
    expect(find.text('Needs review'), findsAtLeastNWidgets(1));
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(PrCard), findsNWidgets(2));
  });

  testWidgets('shows None when empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: const Scaffold(
          body: PrColumn(title: 'Approved', prs: []),
        ),
      ),
    );

    expect(find.text('None'), findsOneWidget);
    expect(find.byType(PrCard), findsNothing);
  });
}
