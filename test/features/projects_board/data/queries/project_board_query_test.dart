// test/features/projects_board/data/queries/project_board_query_test.dart
//
// Test summary:
// - projectBoardQuery selects PullRequest content (isDraft, reviewDecision, CI rollup).
// - It still selects the Issue content the cockpit relies on.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/lead_cockpit/data/queries/project_board.dart';

void main() {
  test('query covers PullRequest content', () {
    expect(projectBoardQuery, contains('... on PullRequest'));
    expect(projectBoardQuery, contains('isDraft'));
    expect(projectBoardQuery, contains('reviewDecision'));
    expect(projectBoardQuery, contains('statusCheckRollup'));
  });

  test('query still covers Issue content', () {
    expect(projectBoardQuery, contains('... on Issue'));
    expect(projectBoardQuery, contains('subIssuesSummary'));
  });
}
