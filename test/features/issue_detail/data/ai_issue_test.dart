// test/features/issue_detail/data/ai_issue_test.dart
//
// Test summary:
// - buildIssueSummaryPrompt embeds title, body, status/priority and asks for bullets.
// - buildNextActionPrompt embeds open sub-issue + linked-PR signals and asks for one action.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/issue_detail/data/repositories/issue_detail_repository.dart';

void main() {
  test('issue summary prompt embeds the issue', () {
    final p = buildIssueSummaryPrompt(sampleIssueDetail);
    expect(p, contains('Rotate API keys'));
    expect(p, contains('bullet'));
  });

  test('next-action prompt asks for one action', () {
    final p = buildNextActionPrompt(sampleIssueDetail);
    expect(p, contains('#482')); // a linked PR signal
    expect(p.toLowerCase(), contains('next'));
  });
}
