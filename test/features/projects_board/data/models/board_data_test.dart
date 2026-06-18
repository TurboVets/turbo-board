// Test summary:
// - BoardCard round-trips through JSON with PR fields.
// - ColumnFacts.isEmpty is true for the default and false when any count is set.
// - boardColumnOrder lists the five visible statuses in board order.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/projects_board/data/models/board_data.dart';

void main() {
  test('BoardCard round-trips through JSON', () {
    const card = BoardCard(
      id: 'p2',
      type: BoardItemType.pullRequest,
      repo: 'mobile-app',
      number: 482,
      title: 'Add biometric auth',
      status: IssueStatus.inProgress,
      priority: IssuePriority.p0,
      points: 8,
      assignees: ['tromero-tv'],
      ciState: PrCiState.passing,
      reviewState: PrReviewState.approved,
      owner: 'TurboVets',
    );
    expect(BoardCard.fromJson(card.toJson()), card);
  });

  test('ColumnFacts.isEmpty reflects whether any signal is present', () {
    expect(const ColumnFacts().isEmpty, isTrue);
    expect(const ColumnFacts(p0Unowned: 1).isEmpty, isFalse);
    expect(const ColumnFacts(ciRedNumbers: [155]).isEmpty, isFalse);
  });

  test('boardColumnOrder is the five visible statuses in order', () {
    expect(boardColumnOrder, [
      IssueStatus.triage,
      IssueStatus.notStarted,
      IssueStatus.inProgress,
      IssueStatus.inReview,
      IssueStatus.done,
    ]);
  });
}
