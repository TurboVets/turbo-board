import 'dart:convert';

import '../../../issue_detail/data/models/issue_detail.dart';
import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../lead_cockpit/presentation/helpers/cockpit_palette.dart';
import '../../../pr_detail/data/models/pr_detail.dart';
import '../../../pr_inbox/data/models/pr_data.dart';
import '../../../projects_board/data/models/board_data.dart' show ProjectBoardData;
import '../../../sprint_report/data/models/sprint_narrative_report.dart';
import '../../../sprint_report/data/models/sprint_report.dart';
import '../../data/models/triage_item.dart';

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
biggest schedule risk, then call out where work is backing up, and end with one
concrete suggestion. Be specific and reference the numbers.

Sprint: ${s.name}, ${s.daysRemaining} days remaining.
Status counts (of ${s.totalIssues}): ${s.done} done, ${s.inProgress} in progress, ${s.inReview} in review,
${s.notStarted} not started, ${s.atRisk} at risk, ${s.unestimated} unestimated.
Aging / stuck items: ${stuck.isEmpty ? 'none' : stuck}.''';
}

// ─── Sprint narratives (Sprint Report + weekly digest) ──────────────────────

String _statusLines(SprintReport r) =>
    r.status.map((s) => '${s.label}: ${s.tickets} tickets / ${s.points} pts').join(', ');

/// Full prose summary of the current sprint for the Sprint Report screen.
String buildSprintSummaryPrompt(SprintReport r) {
  final epics = r.epics.take(5).map((e) => '"${e.title}" ${e.percent}%').join(', ');
  final people = r.people.take(8).map((p) => '${p.handle}: ${p.done}d/${p.open}open').join(', ');
  return '''
You are summarizing an engineering sprint for the whole team. Write 4-6 sentences of plain prose —
no bullets, no heading, no preamble. Cover: overall progress vs commitment, the biggest risk to
finishing on time, where work is concentrated or stuck, and end with one concrete recommendation.
Be specific and cite the numbers.

Sprint: ${r.sprintName} (${r.dateRange}), ${r.daysRemaining} days remaining.
Progress: ${r.pointsDone} of ${r.pointsCommitted} points done (${r.percentDone}%), ${r.totalTickets} tickets across ${r.repoCount} repos.
Forecast: ${r.forecastLabel}${r.behind ? ' (behind)' : ' (on track)'}.
Estimation: ${r.estimatedTickets} estimated, ${r.unestimatedTickets} unestimated.
Status: ${_statusLines(r)}.
Epics: ${epics.isEmpty ? 'none' : epics}.
Per-assignee (done/open): ${people.isEmpty ? 'n/a' : people}.''';
}

/// Scannable bullet digest (standup-style highlights) for the Sprint Report.
String buildSprintDigestPrompt(SprintReport r) {
  return '''
Produce a scannable sprint digest for a team standup. Return ONLY markdown bullets, each starting
with "- ", grouped logically (shipped, in progress / review, at risk, recommendation). 4-7 bullets
total. No heading, no preamble. Be specific and cite numbers.

Sprint: ${r.sprintName}, ${r.daysRemaining} days remaining.
Progress: ${r.pointsDone}/${r.pointsCommitted} points (${r.percentDone}%).
Status: ${_statusLines(r)}.
Forecast: ${r.forecastLabel}.''';
}

/// Weekly team pulse for the Lead Cockpit, framed as the past week from the
/// current board snapshot (throughput = done, risks = overloaded + stuck).
String buildWeeklyDigestPrompt(CockpitData c) {
  final s = c.sprint;
  final shipped = c.team.fold<int>(0, (sum, m) => sum + m.done);
  final stuck = c.stuck.take(5).map((i) => '"${i.title}" (${i.ageDays}d)').join('; ');
  return '''
Write a weekly digest for an engineering team lead reviewing the past week. Return ONLY markdown
bullets, each starting with "- ". 4-6 bullets: what the team shipped, what is in flight,
what is stuck, and what to focus on next week. No heading, no preamble. Cite numbers.

Sprint context: ${s.name}, ${s.daysRemaining} days remaining.
Closed this sprint (throughput): $shipped items; currently ${s.inProgress} in progress, ${s.inReview} in review, ${s.atRisk} at risk.
Stuck items: ${stuck.isEmpty ? 'none' : stuck}.''';
}

// ─── Board triage ──────────────────────────────────────────────────────────

String _ciName(PrCiState s) => switch (s) {
  PrCiState.passing => 'passing',
  PrCiState.pending => 'pending',
  PrCiState.failing => 'failing',
};

String _reviewName(PrReviewState s) => switch (s) {
  PrReviewState.needsReview => 'review required',
  PrReviewState.changesRequested => 'changes requested',
  PrReviewState.approved => 'approved',
  PrReviewState.waitingOnAuthor => 'waiting on author',
};

/// Compact relative-age label for a PR ("3d", "5h", "12m").
String prAgeLabel(DateTime updatedAt, {DateTime? now}) {
  final delta = (now ?? DateTime.now()).difference(updatedAt);
  if (delta.inDays > 0) return '${delta.inDays}d';
  if (delta.inHours > 0) return '${delta.inHours}h';
  if (delta.inMinutes > 0) return '${delta.inMinutes}m';
  return 'now';
}

/// Prompt for AI Board Triage: send every open PR and ask the model to rank the
/// most action-worthy ones (review first / unblock / merge / nudge). The model
/// must reply with a JSON array only — parsed by [parseTriage].
String buildTriagePrompt(List<PrData> prs, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final rows = prs
      .map((p) {
        final age = clock.difference(p.updatedAt).inDays;
        return '- repo: ${p.repo}, number: ${p.number}, title: "${p.title}", '
            'review: ${_reviewName(p.reviewState)}, ci: ${_ciName(p.ciState)}, '
            'draft: ${p.isDraft}, updated: ${age}d ago';
      })
      .join('\n');

  return '''
You are triaging open GitHub pull requests for a busy engineer who watches many repos.
Rank the most action-worthy PRs (at most 5), highest priority first. Prioritize, in order:
1. PRs that need review now (review required, not draft) — especially with failing CI.
2. PRs blocked by failing checks.
3. Approved PRs with passing CI that are ready to merge.
4. Stale PRs (no updates for many days) that need a nudge or close.
Skip draft PRs and anything that needs no action.

Reply with ONLY a JSON array (no prose, no markdown fences). Each element:
{"repo": "owner/name", "number": 123, "category": "review_first|unblock|merge|nudge", "reason": "<= 80 chars, why it matters"}

Open PRs:
$rows''';
}

/// Parses the triage JSON, matching each entry back to a [PrData] by repo +
/// number (so the row can open the right PR). Unmatched / malformed entries are
/// skipped; the result is capped at 5 and re-ranked 1..n.
List<TriageItem> parseTriage(String response, List<PrData> prs, {DateTime? now}) {
  final start = response.indexOf('[');
  final end = response.lastIndexOf(']');
  if (start < 0 || end <= start) return const [];

  final List<dynamic> raw;
  try {
    raw = jsonDecode(response.substring(start, end + 1)) as List<dynamic>;
  } catch (_) {
    return const [];
  }

  final byKey = {for (final p in prs) '${p.repo}#${p.number}': p};
  final items = <TriageItem>[];
  for (final entry in raw) {
    if (entry is! Map<String, dynamic>) continue;
    final repo = entry['repo']?.toString() ?? '';
    final number = entry['number'] is int ? entry['number'] as int : int.tryParse('${entry['number']}');
    if (number == null) continue;
    final pr = byKey['$repo#$number'];
    if (pr == null) continue;
    final reason = entry['reason']?.toString().trim();
    items.add(
      TriageItem(
        rank: items.length + 1,
        repo: pr.repo,
        number: pr.number,
        title: pr.title,
        reason: reason == null || reason.isEmpty ? 'Needs attention' : reason,
        category: TriageCategory.fromWire(entry['category']?.toString()),
        updatedLabel: prAgeLabel(pr.updatedAt, now: now),
      ),
    );
    if (items.length >= 5) break;
  }
  return items;
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

/// 3-bullet TL;DR of an issue, grounded in title + body + key project fields.
String buildIssueSummaryPrompt(IssueDetail i) {
  final fields = [
    if (i.status != null) 'Status: ${_statusName(i.status!)}',
    if (i.priority != null) 'Priority: ${_priorityName(i.priority!)}',
    if (i.points != null) 'Estimate: ${i.points} pts',
    if (i.hasSubIssues) 'Sub-issues: ${i.subDone}/${i.subTotal} done',
    if (i.linkedPrs.isNotEmpty) 'Linked PRs: ${i.linkedPrs.length}',
  ].join(' · ');
  return '''
Summarize this GitHub issue as exactly 3 short bullet points a busy engineer can skim. Each bullet on its own line starting with "- ". No preamble.

Title: ${i.title}
$fields

Body:
${i.bodyMarkdown}
''';
}

/// One terse recommended next action, grounded in state + sub-issues + linked PRs.
String buildNextActionPrompt(IssueDetail i) {
  final signals = <String>[
    'State: ${i.state.name}',
    if (i.hasSubIssues) '${i.subTotal - i.subDone} sub-issues still open',
    for (final pr in i.linkedPrs)
      'PR #${pr.number} (${pr.title}): CI ${pr.ciState.name}, review ${pr.reviewState.name}, ${pr.mergeState.name}',
  ].join('\n');
  return '''
Given this issue's state, recommend the single most useful NEXT action for the assignee, in one short sentence (max ~15 words). No preamble, no bullet — just the sentence.

Issue: ${i.title}
$signals
''';
}

// ─── Board column insights ───────────────────────────────────────────────────

/// One-line-per-column board insight prompt. Grounded in derived facts (not raw
/// cards) so it stays cheap and deterministic. Asks for a JSON object keyed by
/// the column's display label.
String buildBoardInsightsPrompt(ProjectBoardData board) {
  final lines = <String>[];
  for (final col in board.columns) {
    if (col.facts.isEmpty) continue;
    final f = col.facts;
    final parts = <String>[
      if (f.p0Unowned > 0) '${f.p0Unowned} P0 unowned',
      if (f.missingEstimate > 0) '${f.missingEstimate} missing estimate',
      if (f.stuckCount > 0) '${f.stuckCount} stuck',
      if (f.ciRedNumbers.isNotEmpty) 'CI failing on #${f.ciRedNumbers.join(", #")}',
    ];
    lines.add('${col.label} (${col.count} items): ${parts.join("; ")}');
  }
  final facts = lines.isEmpty ? '(no notable signals)' : lines.join('\n');
  return '''
You are triaging a GitHub project board. For each column below, write ONE terse insight line (max ~8 words) a tech lead would care about — what is stuck, unowned, unestimated, or failing CI. Use the exact "·"-separated style, e.g. "2 stuck >4d · 1 P0 blocking · CI red on #155".

Return ONLY a JSON object mapping the column name to its line. Omit columns with nothing notable.

Columns and signals:
$facts
''';
}

/// Parses the model's JSON object (possibly wrapped in prose) into a status map.
/// Keys are matched to [IssueStatus] by display label; empty values are dropped.
Map<IssueStatus, String> parseBoardInsights(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return const {};
  Map<String, dynamic> raw;
  try {
    raw = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (_) {
    return const {};
  }
  final byLabel = {for (final s in IssueStatus.values) CockpitPalette.statusLabel(s).toLowerCase(): s};
  final out = <IssueStatus, String>{};
  raw.forEach((key, value) {
    final status = byLabel[key.trim().toLowerCase()];
    final line = value?.toString().trim() ?? '';
    if (status != null && line.isNotEmpty) out[status] = line;
  });
  return out;
}

// ─── Sprint narrative report ─────────────────────────────────────────────────

/// Prompt for the narrative executive Sprint Report. Asks for a single JSON
/// object matching [SprintNarrativeReport]. Explicitly forbids inventing any
/// metric, date, or name not present in the supplied board data — parsed by
/// [parseSprintReport].
String buildSprintReportPrompt(SprintReport r) {
  final epics = r.epics.take(8).map((e) => '"${e.title}" ${e.percent}%').join(', ');
  final people = r.people.take(10).map((p) => '${p.handle}: ${p.done}d/${p.open}open').join(', ');
  return '''
You are writing an executive end-of-sprint report for engineering leadership, based ONLY on the
board data below. Ground every statement in this data. DO NOT invent metrics, percentages, dates,
customer names, or people that are not present here. Do not include latency, uptime, or coverage
numbers — they are not provided.

Reply with ONLY a JSON object (no prose, no markdown fences), with these keys:
{
  "executiveSummary": "2-3 sentence overview citing the real numbers",
  "keyWins": ["short win", ...],                 // from completed epics / high-progress work
  "deliverables": [{"title": "...", "status": "Complete|In Progress|Released", "description": "<= 8 words", "impact": "<= 8 words"}],
  "techHighlights": {"platform": ["..."], "product": ["..."]},
  "challenges": ["risk grounded in stuck/behind work"],
  "mitigations": ["..."],
  "learnings": ["..."],
  "nextPriorities": ["from unfinished/low-progress epics"],
  "recognition": ["@handle — what they did, from per-assignee load"],
  "outcome": "one-sentence verdict"
}
Omit a key rather than fabricate its contents.

Sprint: ${r.sprintName} (${r.dateRange}), ${r.daysRemaining} days remaining, ${r.repoCount} repos.
Progress: ${r.pointsDone} of ${r.pointsCommitted} points done (${r.percentDone}%), ${r.totalTickets} tickets.
Forecast: ${r.forecastLabel}${r.behind ? ' (behind)' : ' (on track)'}.
Estimation: ${r.estimatedTickets} estimated, ${r.unestimatedTickets} unestimated.
Status: ${_statusLines(r)}.
Epics: ${epics.isEmpty ? 'none' : epics}.
Per-assignee (done/open): ${people.isEmpty ? 'n/a' : people}.''';
}

/// Parses the narrative JSON object defensively. Extracts the first `{`…`}`
/// block, decodes it, and builds the model field-by-field. Returns an empty
/// report on any failure (mirrors [parseTriage]). `overallStatus` is left at its
/// default here — the controller overwrites it from the deterministic forecast.
SprintNarrativeReport parseSprintReport(String response) {
  final start = response.indexOf('{');
  final end = response.lastIndexOf('}');
  if (start < 0 || end <= start) return const SprintNarrativeReport();

  final Map<String, dynamic> raw;
  try {
    raw = jsonDecode(response.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (_) {
    return const SprintNarrativeReport();
  }

  List<String> strs(Object? v) =>
      v is List ? v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() : const [];
  String str(Object? v) => v?.toString().trim() ?? '';

  final deliverables = (raw['deliverables'] is List ? raw['deliverables'] as List : const [])
      .whereType<Map<String, dynamic>>()
      .map(
        (d) => Deliverable(
          title: str(d['title']),
          status: str(d['status']),
          description: str(d['description']),
          impact: str(d['impact']),
        ),
      )
      .toList();

  final th = raw['techHighlights'] is Map<String, dynamic> ? raw['techHighlights'] as Map<String, dynamic> : const {};

  return SprintNarrativeReport(
    executiveSummary: str(raw['executiveSummary']),
    keyWins: strs(raw['keyWins']),
    deliverables: deliverables,
    techHighlights: TechHighlights(platform: strs(th['platform']), product: strs(th['product'])),
    challenges: strs(raw['challenges']),
    mitigations: strs(raw['mitigations']),
    learnings: strs(raw['learnings']),
    nextPriorities: strs(raw['nextPriorities']),
    recognition: strs(raw['recognition']),
    outcome: str(raw['outcome']),
  );
}
