// test/features/pr_inbox/presentation/view/widgets/pr_column_test.dart
//
// Test summary:
// - shows the column title (uppercase) and the item count.
// - renders one PrCard per item; shows 'NOTHING HERE' when empty.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_card.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_column.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';
import 'package:turbo_board/shared/ui/theme/tb_tokens.dart';

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
          body: PrColumn(title: 'NEEDS REVIEW', accent: TbBoard.needsReview, prs: [_pr(1), _pr(2)]),
        ),
      ),
    );

    // 'NEEDS REVIEW' appears in the column header and possibly in review badges
    // on each card — findsAtLeastNWidgets handles both cases.
    expect(find.text('NEEDS REVIEW'), findsAtLeastNWidgets(1));
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(PrCard), findsNWidgets(2));
  });

  testWidgets('shows NOTHING HERE when empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: Scaffold(
          body: PrColumn(title: 'APPROVED', accent: TbBoard.approved, prs: const []),
        ),
      ),
    );

    expect(find.text('NOTHING HERE'), findsOneWidget);
    expect(find.byType(PrCard), findsNothing);
  });
}
