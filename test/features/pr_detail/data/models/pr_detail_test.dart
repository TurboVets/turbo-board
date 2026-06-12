// test/features/pr_detail/data/models/pr_detail_test.dart
//
// Test summary:
// - PrDetail aggregates fields, defaults empty lists, and exposes slug.
// - canDeleteBranch: true only when done (merged/closed), in-repo, branch
//   still exists, not the base branch, and the viewer has write access.
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

  group('canDeleteBranch', () {
    const merged = PrDetail(
      repo: 'o/r',
      number: 7,
      title: 't',
      state: PrState.merged,
      author: 'a',
      baseRefName: 'main',
      headRefName: 'feature',
      headRefId: 'REF_1',
      canMerge: true,
    );

    test('true for a merged in-repo PR with branch + write access', () {
      expect(merged.canDeleteBranch, isTrue);
    });

    test('false when the head ref is already gone', () {
      expect(merged.copyWith(headRefId: null).canDeleteBranch, isFalse);
    });

    test('false for a still-open PR', () {
      expect(merged.copyWith(state: PrState.open).canDeleteBranch, isFalse);
    });

    test('false for a fork (cross-repository) branch', () {
      expect(merged.copyWith(isCrossRepository: true).canDeleteBranch, isFalse);
    });

    test('false without write access', () {
      expect(merged.copyWith(canMerge: false).canDeleteBranch, isFalse);
    });

    test('false when head is the base branch', () {
      expect(merged.copyWith(headRefName: 'main').canDeleteBranch, isFalse);
    });
  });
}
