import '../../../lead_cockpit/data/models/cockpit_data.dart';
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

String _statusName(IssueStatus s) => switch (s) {
  IssueStatus.notStarted => 'Not Started',
  IssueStatus.inProgress => 'In Progress',
  IssueStatus.inReview => 'In Review',
  IssueStatus.triage => 'Triage',
  IssueStatus.done => 'Done',
  IssueStatus.cancelled => 'Cancelled',
};

String _priorityName(IssuePriority p) => switch (p) {
  IssuePriority.p0 => 'P0',
  IssuePriority.p1 => 'P1',
  IssuePriority.p2 => 'P2',
  IssuePriority.p3 => 'P3',
};

/// Prompt for the AI sprint brief on the Lead Cockpit: a short risk narrative
/// for a team lead, grounded in the current board state.
String buildSprintBriefPrompt(CockpitData c) {
  final s = c.sprint;
  final overloaded = c.team.where((m) => m.isOverloaded).map((m) => '${m.handle} (${m.wip} WIP)').join(', ');
  final stuck = c.stuck
      .take(6)
      .map(
        (i) =>
            '"${i.title}" — ${_priorityName(i.priority)}, ${i.ageDays}d in ${_statusName(i.status)}'
            '${i.assignee.isEmpty ? '' : ' (${i.assignee})'}${i.critical ? ', critical' : ''}',
      )
      .join('; ');

  return '''
You are briefing an engineering team lead on the health of their current sprint.
Write 3-4 sentences of plain prose — no bullets, no heading, no preamble. Lead with the single
biggest schedule risk, then call out who is overloaded and where work is backing up, and end with one
concrete suggestion. Be specific and reference the numbers.

Sprint: ${s.name}, ${s.daysRemaining} days remaining.
Status counts (of ${s.totalIssues}): ${s.done} done, ${s.inProgress} in progress, ${s.inReview} in review,
${s.notStarted} not started, ${s.atRisk} at risk, ${s.unestimated} unestimated.
Overloaded members: ${overloaded.isEmpty ? 'none' : overloaded}.
Aging / stuck items: ${stuck.isEmpty ? 'none' : stuck}.''';
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
