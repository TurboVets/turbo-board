// test/features/pr_detail/linked_issues_test.dart
//
// Test summary:
// - prDetailFromNode parses closingIssuesReferences into PrDetail.linkedIssues.
// - the query selects closingIssuesReferences.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_detail/data/queries/pr_detail_query.dart';
import 'package:turbo_board/features/pr_detail/data/repositories/pr_detail_repository.dart';

void main() {
  test('query selects closing issue references', () {
    expect(prDetailQuery, contains('closingIssuesReferences'));
  });

  test('parses linked issues from the node', () {
    final repoNode = <String, dynamic>{'viewerPermission': 'READ'};
    final pr = <String, dynamic>{
      'number': 1,
      'title': 't',
      'state': 'OPEN',
      'author': {'login': 'a'},
      'baseRefName': 'main',
      'headRefName': 'f',
      'closingIssuesReferences': {
        'nodes': [
          {
            'number': 155,
            'title': 'Rotate keys',
            'state': 'OPEN',
            'repository': {'nameWithOwner': 'o/r'},
          },
        ],
      },
    };
    final d = prDetailFromNode('o', 'r', repoNode, pr);
    expect(d.linkedIssues.single.number, 155);
    expect(d.linkedIssues.single.repo, 'o/r');
  });
}
