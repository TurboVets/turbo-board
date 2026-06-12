// test/features/pr_detail/data/queries/pr_detail_query_test.dart
//
// Test summary:
// - the query is a raw doc declaring the owner/name/number variables and key fields.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_detail/data/queries/pr_detail_query.dart';

void main() {
  test('declares variables and key fields', () {
    expect(prDetailQuery, contains(r'$owner: String!'));
    expect(prDetailQuery, contains('pullRequest(number: \$number)'));
    expect(prDetailQuery, contains('statusCheckRollup'));
    expect(prDetailQuery, contains('latestReviews'));
  });
}
