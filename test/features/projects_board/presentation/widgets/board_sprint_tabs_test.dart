// test/features/projects_board/presentation/widgets/board_sprint_tabs_test.dart
//
// Test summary:
// - Renders Current / Previous / Next / All Tasks tabs from the sprint catalog.
// - Defaults the selection to the current sprint.
// - Tapping a tab updates selectedSprintTabProvider.
// - Hides relative tabs that have no neighbouring iteration (no current -> only All Tasks).
// - Renders nothing when the board has no sprints.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';
import 'package:turbo_board/features/projects_board/presentation/view/widgets/board_sprint_tabs.dart';

ProjectBoardData boardWith(List<BoardSprint> sprints) =>
    ProjectBoardData(title: 'B', columns: const [], sprints: sprints);

final _threeSprints = [
  BoardSprint(title: 'Sprint 23', start: DateTime.utc(2026, 5, 20), isCurrent: false),
  BoardSprint(title: 'Sprint 24', start: DateTime.utc(2026, 6, 3), isCurrent: true),
  BoardSprint(title: 'Sprint 25', start: DateTime.utc(2026, 6, 17), isCurrent: false),
];

Future<ProviderContainer> pump(WidgetTester tester, ProjectBoardData board) async {
  final container = ProviderContainer();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: BoardSprintTabs(board: board)),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('renders the four sprint tabs from the catalog', (tester) async {
    await pump(tester, boardWith(_threeSprints));
    expect(find.text('Current Sprint'), findsOneWidget);
    expect(find.text('Previous Sprint'), findsOneWidget);
    expect(find.text('Next Sprint'), findsOneWidget);
    expect(find.text('All Tasks'), findsOneWidget);
  });

  testWidgets('defaults to the current sprint and updates on tap', (tester) async {
    final container = await pump(tester, boardWith(_threeSprints));
    expect(container.read(selectedSprintTabProvider), SprintTab.current);

    await tester.ensureVisible(find.text('All Tasks'));
    await tester.tap(find.text('All Tasks'));
    await tester.pump();
    expect(container.read(selectedSprintTabProvider), SprintTab.all);
  });

  testWidgets('hides relative tabs with no neighbouring iteration', (tester) async {
    // No current iteration -> previous/next/current all resolve away; only All.
    await pump(tester, boardWith([BoardSprint(title: 'Sprint 99', start: DateTime.utc(2030), isCurrent: false)]));
    expect(find.text('Current Sprint'), findsNothing);
    expect(find.text('Previous Sprint'), findsNothing);
    expect(find.text('All Tasks'), findsOneWidget);
  });

  testWidgets('renders nothing when the board has no sprints', (tester) async {
    await pump(tester, boardWith(const []));
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('All Tasks'), findsNothing);
  });
}
