// test/features/pr_detail/presentation/view/widgets/pr_timeline_test.dart
//
// Test summary:
// - renders a comment card per comment/review with author + verb or review badge.
// - renders a compact row for system events (e.g. opened).
// - shows the empty message when no events.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_reviewer.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_timeline_event.dart';
import 'package:turbo_board/features/pr_detail/presentation/view/widgets/pr_timeline.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

void main() {
  testWidgets('renders comment cards, a review badge, and a compact event row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: Scaffold(
          body: PrTimeline(
            events: [
              PrTimelineEvent(author: 'sang', createdAt: DateTime(2026, 6, 10), kind: PrEventKind.opened),
              PrTimelineEvent(
                author: 'tom',
                bodyMarkdown: 'hi',
                createdAt: DateTime(2026, 6, 10, 1),
                kind: PrEventKind.comment,
              ),
              PrTimelineEvent(
                author: 'mira',
                bodyMarkdown: 'changes',
                createdAt: DateTime(2026, 6, 10, 2),
                kind: PrEventKind.reviewComment,
                reviewState: PrReviewerState.changesRequested,
              ),
            ],
          ),
        ),
      ),
    );

    // Compact opened event.
    expect(find.textContaining('opened this pull request'), findsOneWidget);
    // Comment card with the plain-comment verb.
    expect(find.text('tom'), findsOneWidget);
    expect(find.text('left a comment'), findsOneWidget);
    // Review comment carries the badge instead of the verb.
    expect(find.text('mira'), findsOneWidget);
    expect(find.text('CHANGES REQ'), findsOneWidget);
  });

  testWidgets('shows empty message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: const Scaffold(body: PrTimeline(events: [])),
      ),
    );
    expect(find.textContaining('No conversation'), findsOneWidget);
  });
}
