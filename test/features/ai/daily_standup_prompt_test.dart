// Test summary:
// - buildDailyStandupPrompt asks for the three IN REVIEW / BLOCKED / NEXT sections
// - it cites the sprint name and status counts
// - it extracts in-review items (with handle + age) from the team's member items
// - it lists stuck items, and degrades to "none" when there are none
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/lead_cockpit/data/models/cockpit_data.dart';

final _emptyFlow = SprintFlow(start: DateTime(2026, 6, 20), end: DateTime(2026, 6, 24));

CockpitData _cockpit({List<TeamMemberLoad> team = const [], List<StuckIssue> stuck = const []}) => CockpitData(
  sprint: const SprintHealth(
    name: 'Sprint 24',
    daysRemaining: 4,
    endLabel: 'Jun 24',
    totalIssues: 47,
    repoCount: 3,
    done: 20,
    inProgress: 8,
    inReview: 5,
    notStarted: 11,
    atRisk: 3,
    unestimated: 6,
  ),
  team: team,
  stuck: stuck,
  flow: _emptyFlow,
);

void main() {
  test('asks for the three standup sections', () {
    final p = buildDailyStandupPrompt(_cockpit());
    expect(p, contains('IN REVIEW'));
    expect(p, contains('BLOCKED'));
    expect(p, contains('NEXT'));
  });

  test('cites sprint name and status counts', () {
    final p = buildDailyStandupPrompt(_cockpit());
    expect(p, contains('Sprint 24'));
    expect(p, contains('20 done'));
    expect(p, contains('5 in review'));
    expect(p, contains('6 unestimated'));
  });

  test('extracts in-review items from team member items with handle and age', () {
    final p = buildDailyStandupPrompt(
      _cockpit(
        team: const [
          TeamMemberLoad(
            handle: 'alice',
            wip: 2,
            inReview: 1,
            stuck: 0,
            items: [
              MemberItem(title: 'Refactor auth', status: IssueStatus.inReview, ageDays: 2),
              MemberItem(title: 'Build dashboard', status: IssueStatus.inProgress),
            ],
          ),
        ],
      ),
    );
    expect(p, contains('"Refactor auth" (alice, 2d)'));
    // In-progress items are not part of the "in review now" list.
    expect(p, isNot(contains('Build dashboard')));
  });

  test('lists stuck items, and says none when empty', () {
    expect(buildDailyStandupPrompt(_cockpit()), contains('Blocked / stuck items (0 critical): none'));
    final p = buildDailyStandupPrompt(
      _cockpit(
        stuck: const [
          StuckIssue(
            title: 'Flaky CI',
            repo: 'org/app',
            assignee: 'bob',
            priority: IssuePriority.p1,
            status: IssueStatus.inReview,
            ageDays: 5,
            prLabel: '#88',
            critical: true,
          ),
        ],
      ),
    );
    expect(p, contains('"Flaky CI" — 5d in In Review (bob), CRITICAL'));
    // The critical count is surfaced so NEXT can be made to cover every one.
    expect(p, contains('Blocked / stuck items (1 critical):'));
  });

  test('includes the snapshot header format with done/at-risk/unestimated', () {
    final p = buildDailyStandupPrompt(_cockpit());
    expect(p, contains('Sprint 24 · 4d left · 20/47 done · 3 at risk · 6 unestimated'));
  });
}
