// Test summary:
// - parseBullets strips -, *, • markers and drops blank lines
// - buildSummaryPrompt includes title, description, and diff; truncates long diffs
// - buildSummaryPrompt notes missing description / omits empty diff
// - buildReplyPrompt includes the intent instruction, title, and author
// - ReplyIntent labels are stable
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';

PrDetail _detail({String body = 'Adds a thing.'}) => PrDetail(
  repo: 'org/app',
  number: 42,
  title: 'Add rate limiting',
  state: PrState.open,
  author: 'alex',
  baseRefName: 'main',
  headRefName: 'feature',
  bodyMarkdown: body,
);

void main() {
  group('parseBullets', () {
    test('strips markers and blank lines', () {
      const raw = '- First\n* Second\n• Third\n\n   \n';
      expect(parseBullets(raw), ['First', 'Second', 'Third']);
    });
  });

  group('buildSummaryPrompt', () {
    test('includes title, description, and diff', () {
      final p = buildSummaryPrompt(_detail(), 'diff --git a b');
      expect(p, contains('Add rate limiting'));
      expect(p, contains('Adds a thing.'));
      expect(p, contains('diff --git a b'));
      expect(p, contains('three bullet'));
    });

    test('truncates an oversized diff', () {
      final hugeDiff = 'x' * (maxDiffChars + 500);
      final p = buildSummaryPrompt(_detail(), hugeDiff);
      expect(p, contains('(diff truncated)'));
      expect(p.contains('x' * (maxDiffChars + 1)), isFalse);
    });

    test('notes missing description and omits empty diff', () {
      final p = buildSummaryPrompt(_detail(body: ''), '');
      expect(p, contains('(no description)'));
      expect(p, isNot(contains('Diff:')));
    });
  });

  group('buildReplyPrompt', () {
    test('includes intent instruction, title and author', () {
      final p = buildReplyPrompt(_detail(), ReplyIntent.nudgeReviewer);
      expect(p, contains('nudge'));
      expect(p, contains('Add rate limiting'));
      expect(p, contains('alex'));
    });
  });

  test('intent labels', () {
    expect(ReplyIntent.nudgeReviewer.label, 'Nudge reviewer');
    expect(ReplyIntent.requestChanges.label, 'Request changes');
    expect(ReplyIntent.approve.label, 'Approve');
    expect(ReplyIntent.askForUpdate.label, 'Ask for update');
  });
}
