// Test summary:
// - parseBullets strips -, *, • markers and drops blank lines
// - buildSummaryPrompt includes title, description, and diff; truncates long diffs
// - buildSummaryPrompt notes missing description / omits empty diff
// - buildReplyPrompt includes the intent instruction, title, and author
// - ReplyIntent labels are stable
// - buildTriagePrompt lists each PR with repo/number/state and the ranking rules
// - parseTriage matches entries by repo+number, re-ranks, caps at 5, maps category
// - parseTriage tolerates prose around the JSON and drops malformed/unknown entries
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/data/models/triage_item.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';

SprintReport _report() => const SprintReport(
  sprintName: 'Sprint 24',
  dateRange: 'Jun 2 – Jun 16',
  daysRemaining: 6,
  totalTickets: 60,
  pointsCommitted: 168,
  repoCount: 4,
  forecastLabel: 'Trending ~2D behind',
  forecastDetail: '58 of 133 done',
  pointsDone: 84,
  estimatedTickets: 48,
  estimatedPoints: 168,
  unestimatedTickets: 12,
  burndown: Burndown(committedPoints: 168, totalDays: 14, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 14),
  status: [StatusSlice(kind: ReportStatusKind.done, label: 'Done', tickets: 30, points: 84)],
);

CockpitData _cockpit() => const CockpitData(
  sprint: SprintHealth(
    name: 'Sprint 24',
    daysRemaining: 6,
    endLabel: 'Jun 16',
    totalIssues: 60,
    repoCount: 4,
    done: 30,
    inProgress: 12,
    inReview: 8,
    notStarted: 7,
    atRisk: 3,
    unestimated: 12,
  ),
  team: [TeamMemberLoad(handle: 'sam', wip: 6, inReview: 1, stuck: 0, done: 9, points: 38)],
  stuck: [],
);

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

PrData _pr({
  String repo = 'org/app',
  int number = 1,
  String title = 'A PR',
  PrReviewState review = PrReviewState.needsReview,
  PrCiState ci = PrCiState.passing,
  DateTime? updatedAt,
}) => PrData(
  repo: repo,
  number: number,
  title: title,
  author: 'alex',
  reviewState: review,
  ciState: ci,
  updatedAt: updatedAt ?? DateTime(2026, 6, 10),
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

  group('buildTriagePrompt', () {
    test('lists each PR and the ranking rules', () {
      final now = DateTime(2026, 6, 12);
      final p = buildTriagePrompt([
        _pr(repo: 'org/api', number: 7, title: 'Fix login', updatedAt: DateTime(2026, 6, 9)),
        _pr(repo: 'org/web', number: 12, ci: PrCiState.failing),
      ], now: now);
      expect(p, contains('org/api'));
      expect(p, contains('number: 7'));
      expect(p, contains('Fix login'));
      expect(p, contains('3d ago')); // Jun 12 - Jun 9
      expect(p, contains('JSON array'));
      expect(p, contains('review_first'));
    });
  });

  group('parseTriage', () {
    final prs = [
      _pr(repo: 'org/api', number: 7, title: 'Fix login', updatedAt: DateTime(2026, 6, 9)),
      _pr(repo: 'org/web', number: 12, title: 'Bump deps'),
    ];

    test('matches by repo+number, re-ranks, and maps category', () {
      const raw =
          '[{"repo":"org/web","number":12,"category":"merge","reason":"green & approved"},'
          '{"repo":"org/api","number":7,"category":"review_first","reason":"needs review"}]';
      final items = parseTriage(raw, prs, now: DateTime(2026, 6, 12));
      expect(items, hasLength(2));
      expect(items[0].rank, 1);
      expect(items[0].repo, 'org/web');
      expect(items[0].category, TriageCategory.merge);
      expect(items[0].title, 'Bump deps'); // pulled from PrData, not the model
      expect(items[1].rank, 2);
      expect(items[1].category, TriageCategory.reviewFirst);
      expect(items[1].updatedLabel, '3d');
    });

    test('tolerates surrounding prose and drops unmatched / malformed entries', () {
      const raw =
          'Here you go:\n'
          '[{"repo":"org/api","number":7,"category":"unblock","reason":"red CI"},'
          '{"repo":"org/ghost","number":99,"category":"merge","reason":"nope"},'
          '{"number":"bad"}]\nDone.';
      final items = parseTriage(raw, prs);
      expect(items, hasLength(1));
      expect(items.single.repo, 'org/api');
      expect(items.single.category, TriageCategory.unblock);
    });

    test('caps the result at 5', () {
      final many = [for (var i = 1; i <= 8; i++) _pr(repo: 'org/api', number: i)];
      final raw =
          '[${many.map((p) => '{"repo":"org/api","number":${p.number},"category":"nudge","reason":"x"}').join(',')}]';
      expect(parseTriage(raw, many), hasLength(5));
    });

    test('returns empty when there is no JSON array', () {
      expect(parseTriage('no json here', prs), isEmpty);
      expect(parseTriage('{not an array}', prs), isEmpty);
    });

    test('unknown category falls back to watch', () {
      const raw = '[{"repo":"org/api","number":7,"category":"explode","reason":"?"}]';
      expect(parseTriage(raw, prs).single.category, TriageCategory.watch);
    });
  });

  group('sprint narratives', () {
    test('summary prompt embeds sprint name + progress', () {
      final p = buildSprintSummaryPrompt(_report());
      expect(p, contains('Sprint 24'));
      expect(p, contains('50%')); // percentDone = 84/168
      expect(p, contains('6 days'));
    });

    test('digest prompt asks for bullets + embeds counts', () {
      final p = buildSprintDigestPrompt(_report());
      expect(p.toLowerCase(), contains('bullet'));
      expect(p, contains('84')); // points done
    });

    test('weekly digest prompt frames the week + names the sprint', () {
      final p = buildWeeklyDigestPrompt(_cockpit());
      expect(p.toLowerCase(), contains('week'));
      expect(p, contains('Sprint 24'));
    });
  });
}
