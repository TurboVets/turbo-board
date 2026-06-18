// test/features/issue_detail/data/queries/issue_queries_test.dart
//
// Test summary:
// - issueDetailQuery selects issue identity, body, project fields, sub-issues, linked PRs, timeline, viewerCanUpdate.
// - mutation strings cover addComment, closeIssue, reopenIssue, createLinkedBranch.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/issue_detail/data/queries/issue_detail_query.dart';
import 'package:turbo_board/features/issue_detail/data/queries/issue_mutations.dart';

void main() {
  test('issueDetailQuery covers the fields the mapper reads', () {
    for (final fragment in [
      'issue(number: \$number)',
      'viewerCanUpdate',
      'subIssuesSummary',
      'subIssues(',
      'closedByPullRequestsReferences',
      'projectItems',
      'timelineItems',
      'defaultBranchRef',
    ]) {
      expect(issueDetailQuery, contains(fragment), reason: 'missing $fragment');
    }
  });

  test('mutations cover comment/close/reopen/branch', () {
    expect(addIssueCommentMutation, contains('addComment'));
    expect(closeIssueMutation, contains('closeIssue'));
    expect(reopenIssueMutation, contains('reopenIssue'));
    expect(createLinkedBranchMutation, contains('createLinkedBranch'));
  });
}
