// test/features/pr_detail/presentation/view/widgets/pr_timeline_test.dart
//
// Test summary:
// - renders one tile per event with author + a review badge for review events.
// - shows the empty message when no events.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_reviewer.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_timeline_event.dart';
import 'package:turbo_board/features/pr_detail/presentation/view/widgets/pr_timeline.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

void main() {
  testWidgets('renders a tile per event with review badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: getAppTheme(),
        home: Scaffold(
          body: PrTimeline(
            events: [
              PrTimelineEvent(
                author: 'tom',
                bodyMarkdown: 'hi',
                createdAt: DateTime(2026, 6, 10),
                kind: PrEventKind.comment,
              ),
              PrTimelineEvent(
                author: 'sang',
                bodyMarkdown: 'changes',
                createdAt: DateTime(2026, 6, 10, 1),
                kind: PrEventKind.review,
                reviewState: PrReviewerState.changesRequested,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PrTimelineTile), findsNWidgets(2));
    expect(find.text('tom'), findsOneWidget);
    expect(find.text('sang'), findsOneWidget);
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
