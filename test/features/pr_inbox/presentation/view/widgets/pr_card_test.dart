// test/features/pr_inbox/presentation/view/widgets/pr_card_test.dart
//
// Test summary:
// - renders the title, repo slug with number, and author for a PR.
// - shows a CONFLICTS badge when the PR is conflicting with its base branch.
// - hides the CONFLICTS badge when the PR is mergeable or unknown.
// - dims (Opacity 0.55) a draft PR card and shows WAITING (not NEEDS REVIEW)
//   even when the draft's GitHub review state is needsReview.
// - renders a non-draft card at full opacity.
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

  PrData prWith(PrMergeState mergeState) => PrData(
    repo: 'o/r',
    number: 42,
    title: 'Add rate limiting',
    author: 'sang',
    reviewState: PrReviewState.needsReview,
    ciState: PrCiState.passing,
    mergeState: mergeState,
    updatedAt: DateTime(2026, 6, 10),
  );

  testWidgets('shows CONFLICTS badge when conflicting', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: Scaffold(body: PrCard(pr: prWith(PrMergeState.conflicting))),
      ),
    );

    expect(find.textContaining('CONFLICTS'), findsOneWidget);
  });

  testWidgets('hides CONFLICTS badge when mergeable or unknown', (tester) async {
    for (final state in [PrMergeState.mergeable, PrMergeState.unknown]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: getAppTheme(),
          home: Scaffold(body: PrCard(pr: prWith(state))),
        ),
      );

      expect(find.textContaining('CONFLICTS'), findsNothing, reason: 'state=$state');
    }
  });

  PrData draftPr({required bool isDraft, PrReviewState reviewState = PrReviewState.needsReview}) => PrData(
    repo: 'o/r',
    number: 7,
    title: 'WIP feature',
    author: 'sang',
    isDraft: isDraft,
    reviewState: reviewState,
    ciState: PrCiState.passing,
    updatedAt: DateTime(2026, 6, 10),
  );

  double cardOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(find.descendant(of: find.byType(PrCard), matching: find.byType(Opacity)).first).opacity;

  testWidgets('dims a draft card and shows WAITING instead of NEEDS REVIEW', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: Scaffold(body: PrCard(pr: draftPr(isDraft: true))),
      ),
    );

    expect(cardOpacity(tester), 0.55);
    // Draft is not up for review yet — review badge reads WAITING, never NEEDS REVIEW.
    expect(find.text('WAITING'), findsOneWidget);
    expect(find.text('NEEDS REVIEW'), findsNothing);
    // The inline DRAFT chip still marks it as a draft.
    expect(find.text('DRAFT'), findsOneWidget);
  });

  testWidgets('renders a non-draft card at full opacity with its real review badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: Scaffold(body: PrCard(pr: draftPr(isDraft: false))),
      ),
    );

    expect(cardOpacity(tester), 1.0);
    expect(find.text('NEEDS REVIEW'), findsOneWidget);
    expect(find.text('DRAFT'), findsNothing);
  });
}
