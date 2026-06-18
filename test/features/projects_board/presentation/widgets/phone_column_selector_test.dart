// Test summary:
// - Renders a pill per column with its label and count.
// - Tapping a pill calls onSelect with its index.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/view/widgets/phone_column_selector.dart';

const _cols = [
  BoardColumn(status: IssueStatus.triage, label: 'Triage'),
  BoardColumn(
    status: IssueStatus.inProgress,
    label: 'In Progress',
    cards: [
      BoardCard(
        id: 'o/r#1',
        type: BoardItemType.issue,
        owner: 'o',
        repo: 'r',
        number: 1,
        title: 'x',
        status: IssueStatus.inProgress,
      ),
    ],
  ),
];

void main() {
  testWidgets('renders pills and reports taps', (tester) async {
    var picked = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhoneColumnSelector(columns: _cols, selectedIndex: 0, onSelect: (i) => picked = i),
        ),
      ),
    );
    expect(find.textContaining('In Progress'), findsOneWidget);
    await tester.tap(find.textContaining('In Progress'));
    expect(picked, 1);
  });
}
