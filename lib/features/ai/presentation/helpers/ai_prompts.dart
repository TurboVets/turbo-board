import '../../../pr_detail/data/models/pr_detail.dart';

/// Canned reply intents for the Reply Drafter.
enum ReplyIntent { nudgeReviewer, requestChanges, approve, askForUpdate }

extension ReplyIntentLabel on ReplyIntent {
  String get label => switch (this) {
    ReplyIntent.nudgeReviewer => 'Nudge reviewer',
    ReplyIntent.requestChanges => 'Request changes',
    ReplyIntent.approve => 'Approve',
    ReplyIntent.askForUpdate => 'Ask for update',
  };

  String get _instruction => switch (this) {
    ReplyIntent.nudgeReviewer => 'a polite nudge asking the assigned reviewers to take a look when they have a moment',
    ReplyIntent.requestChanges => 'a constructive request for changes, specific and respectful',
    ReplyIntent.approve => 'a brief, warm approval comment',
    ReplyIntent.askForUpdate => 'a friendly request to the author for a status update',
  };
}

/// Diff is truncated to keep prompts (and cost) bounded.
const int maxDiffChars = 12000;

String _truncateDiff(String diff) =>
    diff.length <= maxDiffChars ? diff : '${diff.substring(0, maxDiffChars)}\n…(diff truncated)';

/// Prompt for the 3-bullet PR summary. [diff] may be empty if unavailable.
String buildSummaryPrompt(PrDetail detail, String diff) {
  final body = detail.bodyMarkdown.trim().isEmpty ? '(no description)' : detail.bodyMarkdown.trim();
  final diffSection = diff.trim().isEmpty ? '' : '\n\nDiff:\n${_truncateDiff(diff)}';
  return '''
Summarize this GitHub pull request as exactly three concise bullet points (a TL;DR for a busy reviewer).
Return only the three bullets, each starting with "- ". No preamble, no heading.

Title: ${detail.title}
Repository: ${detail.repo}
Base: ${detail.baseRefName} ← Head: ${detail.headRefName}

Description:
$body$diffSection''';
}

/// Prompt for an editable reply draft in the given [intent].
String buildReplyPrompt(PrDetail detail, ReplyIntent intent) {
  return '''
Write ${intent._instruction} for this GitHub pull request, as a comment the user can post.
Keep it short (1-3 sentences), professional, and ready to paste. Return only the comment text.

PR: ${detail.title} (${detail.slug})
Author: ${detail.author}''';
}

/// Splits the model's bullet response into clean lines (no leading markers).
List<String> parseBullets(String response) {
  return response
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) => l.replaceFirst(RegExp(r'^[-*•]\s*'), ''))
      .where((l) => l.isNotEmpty)
      .toList();
}
