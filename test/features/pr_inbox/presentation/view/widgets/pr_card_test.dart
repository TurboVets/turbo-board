// test/features/pr_inbox/presentation/view/widgets/pr_card_test.dart
//
// Test summary:
// - renders the title, repo slug with number, and author for a PR.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/presentation/view/widgets/pr_card.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

void main() {
  testWidgets('renders title, slug and author', (tester) async {
    final pr = PrData(
      repo: 'o/r',
      number: 42,
      title: 'Add rate limiting',
      author: 'sang',
      reviewState: PrReviewState.needsReview,
      ciState: PrCiState.passing,
      updatedAt: DateTime(2026, 6, 10),
      commentsCount: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: Scaffold(body: PrCard(pr: pr)),
      ),
    );

    expect(find.text('Add rate limiting'), findsOneWidget);
    // Repo slug 'o/r' and '#42' are rendered as separate TextSpan runs in the
    // same RichText; textContaining matches within the rendered inline text.
    expect(find.textContaining('o/r'), findsAtLeastNWidgets(1));
    expect(find.textContaining('#42'), findsAtLeastNWidgets(1));
    expect(find.textContaining('sang'), findsAtLeastNWidgets(1));
  });
}
