// test/features/projects_board/presentation/widgets/board_card_test.dart
//
// Test summary:
// - Renders title, repo, #number and the priority badge.
// - PR card shows CI + Rev dots; draft PR shows the Draft badge.
// - Issue card shows neither CI/Rev dots nor Draft.
// - Non-draft PR card shows CI/Rev but no Draft badge.
// - P0 card paints the #5E2230 border.
// - Tapping invokes onTap.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/view/widgets/board_card.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('PR draft card shows draft badge, CI and Rev dots', (tester) async {
    await tester.pumpWidget(
      _host(
        BoardCardTile(
          card: const BoardCard(
            id: 'o/r#86',
            type: BoardItemType.pullRequest,
            owner: 'o',
            repo: 'design-system',
            number: 86,
            title: 'Deprecate legacy buttons',
            status: IssueStatus.inProgress,
            priority: IssuePriority.p3,
            isDraft: true,
            ciState: PrCiState.pending,
            reviewState: PrReviewState.review,
          ),
          onTap: () {},
        ),
      ),
    );
    expect(find.textContaining('Deprecate legacy buttons'), findsOneWidget);
    expect(find.text('#86'), findsOneWidget);
    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.text('CI'), findsOneWidget);
    expect(find.text('REV'), findsOneWidget);
  });

  testWidgets('issue card has no CI/Rev or draft', (tester) async {
    await tester.pumpWidget(
      _host(
        BoardCardTile(
          card: const BoardCard(
            id: 'o/r#301',
            type: BoardItemType.issue,
            owner: 'o',
            repo: 'api-gateway',
            number: 301,
            title: 'Investigate 504s',
            status: IssueStatus.triage,
            priority: IssuePriority.p0,
          ),
          onTap: () {},
        ),
      ),
    );
    expect(find.text('CI'), findsNothing);
    expect(find.text('DRAFT'), findsNothing);
    expect(find.text('P0'), findsOneWidget);
  });

  testWidgets('non-draft PR card shows CI/Rev but no Draft badge', (tester) async {
    await tester.pumpWidget(
      _host(
        BoardCardTile(
          card: const BoardCard(
            id: 'o/r#12',
            type: BoardItemType.pullRequest,
            owner: 'o',
            repo: 'api-gateway',
            number: 12,
            title: 'Add rate limiting',
            status: IssueStatus.inProgress,
            priority: IssuePriority.p2,
            isDraft: false,
            ciState: PrCiState.passing,
            reviewState: PrReviewState.approved,
          ),
          onTap: () {},
        ),
      ),
    );
    expect(find.text('DRAFT'), findsNothing);
    expect(find.text('CI'), findsOneWidget);
    expect(find.text('REV'), findsOneWidget);
  });

  testWidgets('P0 card paints #5E2230 border', (tester) async {
    await tester.pumpWidget(
      _host(
        BoardCardTile(
          card: const BoardCard(
            id: 'o/r#301',
            type: BoardItemType.issue,
            owner: 'o',
            repo: 'api-gateway',
            number: 301,
            title: 'Investigate 504s',
            status: IssueStatus.triage,
            priority: IssuePriority.p0,
          ),
          onTap: () {},
        ),
      ),
    );
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final decoration = widget.decoration;
          if (decoration is BoxDecoration && decoration.border != null) {
            final border = decoration.border! as Border;
            return border.top.color == const Color(0xFF5E2230);
          }
        }
        return false;
      }),
      findsOneWidget,
    );
  });

  testWidgets('tap fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        BoardCardTile(
          card: const BoardCard(
            id: 'o/r#1',
            type: BoardItemType.issue,
            owner: 'o',
            repo: 'r',
            number: 1,
            title: 'X',
            status: IssueStatus.done,
            priority: IssuePriority.p2,
          ),
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.tap(find.byType(BoardCardTile));
    expect(tapped, isTrue);
  });
}
