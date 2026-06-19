// test/features/projects_board/presentation/widgets/board_column_test.dart
//
// Test summary:
// - Renders the column label, count, and its cards.
// - Empty column shows the "No items" placeholder.
// - When the insights controller holds a line for this status, the AI insight row renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart'; // for the Override type (not in the main barrel)
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';
import 'package:turbo_board/features/projects_board/presentation/view/widgets/board_column.dart';

const _col = BoardColumn(
  status: IssueStatus.inProgress,
  label: 'In Progress',
  cards: [
    BoardCard(
      id: 'o/r#1',
      type: BoardItemType.issue,
      owner: 'o',
      repo: 'r',
      number: 1,
      title: 'Card one',
      status: IssueStatus.inProgress,
      priority: IssuePriority.p1,
    ),
  ],
);

Widget _host(Widget child, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('renders label, count, cards', (tester) async {
    await tester.pumpWidget(_host(BoardColumnView(column: _col, width: 236, onCardTap: (_) {})));
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Card one'), findsOneWidget);
  });

  testWidgets('empty column shows placeholder', (tester) async {
    await tester.pumpWidget(
      _host(
        const BoardColumnView(
          column: BoardColumn(status: IssueStatus.done, label: 'Done'),
          width: 236,
          onCardTap: _noop,
        ),
      ),
    );
    expect(find.text('No items'), findsOneWidget);
  });

  testWidgets('shows AI insight line when controller has one', (tester) async {
    await tester.pumpWidget(
      _host(
        BoardColumnView(column: _col, width: 236, onCardTap: (_) {}),
        overrides: [
          boardInsightsControllerProvider.overrideWith(() => _StubInsights({IssueStatus.inProgress: '1 P0 blocking'})),
        ],
      ),
    );
    expect(find.text('1 P0 blocking'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
  });
}

void _noop(BoardCard _) {}

class _StubInsights extends BoardInsightsController {
  _StubInsights(this._data);
  final Map<IssueStatus, String> _data;
  @override
  AsyncValue<Map<IssueStatus, String>>? build() => AsyncValue.data(_data);
}
