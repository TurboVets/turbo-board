// test/features/pr_inbox/data/queries/search_open_prs_test.dart
//
// Test summary:
// - buildSearchQueryString prefixes is:pr is:open and adds a repo: term per slug.
// - slugs are deduped and sorted for a stable query.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/queries/search_open_prs.dart';

void main() {
  test('builds an is:pr is:open query with repo terms', () {
    final q = buildSearchQueryString(['o/b', 'o/a']);
    expect(q, 'is:pr is:open repo:o/a repo:o/b');
  });

  test('dedupes repeated slugs', () {
    final q = buildSearchQueryString(['o/a', 'o/a', 'o/b']);
    expect(q, 'is:pr is:open repo:o/a repo:o/b');
  });
}
