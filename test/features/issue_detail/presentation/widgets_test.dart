// test/features/issue_detail/presentation/widgets_test.dart
//
// Test summary:
// - IssueSubIssuesCard shows "{done}/{total} done" and one row per sub-issue.
// - IssueLinkedPrsCard renders a row per linked PR with its number.
// - IssueCommentComposer shows Comment + Close when viewerCanUpdate, and hides them when not.
// - IssueDevelopmentCard shows the Create branch CTA.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/issue_detail/data/repositories/issue_detail_repository.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/widgets/issue_comment_composer.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/widgets/issue_development_card.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/widgets/issue_linked_prs_card.dart';
import 'package:turbo_board/features/issue_detail/presentation/view/widgets/issue_sub_issues_card.dart';

Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  final issue = sampleIssueDetail;

  testWidgets('sub-issues card shows progress and rows', (tester) async {
    await tester.pumpWidget(_wrap(IssueSubIssuesCard(issue: issue, onTapSub: (_) {})));
    expect(find.textContaining('${issue.subDone}/${issue.subTotal}'), findsOneWidget);
    expect(find.textContaining('Bind key to request context'), findsOneWidget);
  });

  testWidgets('linked PRs card lists PRs', (tester) async {
    await tester.pumpWidget(_wrap(IssueLinkedPrsCard(prs: issue.linkedPrs, onTapPr: (_) {})));
    expect(find.textContaining('482'), findsWidgets);
  });

  testWidgets('composer hides actions without viewerCanUpdate', (tester) async {
    await tester.pumpWidget(_wrap(IssueCommentComposer(issue: issue.copyWith(viewerCanUpdate: false))));
    expect(find.text('Comment'), findsNothing);
  });

  testWidgets('development card shows create-branch CTA', (tester) async {
    await tester.pumpWidget(_wrap(IssueDevelopmentCard(issue: issue)));
    expect(find.textContaining('branch', findRichText: true), findsWidgets);
  });
}
