// test/features/projects_board/presentation/providers/board_assignee_filter_test.dart
//
// Test summary:
// - boardAssignees collects, dedupes, and sorts every assignee on the board.
// - filterBoardByAssignees returns the board unchanged when the filter is empty.
// - filtering by a login keeps only that user's cards.
// - filtering by kBoardUnassigned keeps only cards with no assignee.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';
import 'package:turbo_board/features/projects_board/presentation/providers/projects_board_provider.dart';

BoardCard _card(int n, {List<String> assignees = const []}) => BoardCard(
  id: 'o/r#$n',
  type: BoardItemType.issue,
  repo: 'r',
  number: n,
  title: 'Card $n',
  status: IssueStatus.inProgress,
  assignees: assignees,
);

ProjectBoardData _board() => ProjectBoardData(
  title: 'B',
  columns: [
    BoardColumn(
      status: IssueStatus.inProgress,
      label: 'In Progress',
      cards: [
        _card(1, assignees: ['bob', 'alice']),
        _card(2, assignees: ['alice']),
        _card(3), // unassigned
      ],
    ),
  ],
);

int _cardCount(ProjectBoardData b) => b.columns.fold(0, (s, c) => s + c.cards.length);

void main() {
  test('boardAssignees dedupes and sorts', () {
    expect(boardAssignees(_board()), ['alice', 'bob']);
  });

  test('empty filter leaves the board unchanged', () {
    final b = _board();
    expect(filterBoardByAssignees(b, const {}), b);
  });

  test('filtering by a login keeps only that user\'s cards', () {
    final out = filterBoardByAssignees(_board(), {'alice'});
    expect(_cardCount(out), 2);
    expect(out.columns.first.cards.map((c) => c.number), [1, 2]);
  });

  test('filtering by unassigned keeps only cards with no assignee', () {
    final out = filterBoardByAssignees(_board(), {kBoardUnassigned});
    expect(_cardCount(out), 1);
    expect(out.columns.first.cards.single.number, 3);
  });
}
