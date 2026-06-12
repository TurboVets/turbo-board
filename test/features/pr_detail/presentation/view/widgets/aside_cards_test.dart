// test/features/pr_detail/presentation/view/widgets/aside_cards_test.dart
//
// Test summary:
// - PrReviewersCard renders a reviewer + state badge; empty message otherwise.
// - PrCommitCard renders the headline and abbreviated oid.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_commit.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_reviewer.dart';
import 'package:turbo_board/features/pr_detail/presentation/view/widgets/pr_commit_card.dart';
import 'package:turbo_board/features/pr_detail/presentation/view/widgets/pr_reviewers_card.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

void main() {
  testWidgets('reviewers card shows login + badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: const Scaffold(
          body: PrReviewersCard(
            reviewers: [PrReviewer(login: 'sang', state: PrReviewerState.approved)],
          ),
        ),
      ),
    );
    expect(find.text('sang'), findsOneWidget);
    expect(find.text('APPROVED'), findsOneWidget);
  });

  testWidgets('commit card shows headline + oid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: Scaffold(
          body: PrCommitCard(
            commit: const PrCommit(abbreviatedOid: 'a1b2c3d', messageHeadline: 'Fix bug'),
          ),
        ),
      ),
    );
    expect(find.text('Fix bug'), findsOneWidget);
    expect(find.textContaining('a1b2c3d'), findsOneWidget);
  });
}
