// test/features/pr_detail/data/models/pr_detail_test.dart
//
// Test summary:
// - PrDetail aggregates fields, defaults empty lists, and exposes slug.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';

void main() {
  test('defaults and slug', () {
    const d = PrDetail(
      repo: 'o/r',
      number: 7,
      title: 't',
      state: PrState.open,
      author: 'a',
      baseRefName: 'main',
      headRefName: 'feature',
    );
    expect(d.slug, 'o/r#7');
    expect(d.checks, isEmpty);
    expect(d.reviewers, isEmpty);
    expect(d.timeline, isEmpty);
    expect(d.bodyMarkdown, '');
    expect(d.isDraft, isFalse);
  });
}
