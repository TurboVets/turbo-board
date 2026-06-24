// Test summary:
// - buildSprintReportPrompt forbids inventing metrics and cites real numbers
// - parseSprintReport reads a fenced/loose JSON object into the model
// - parseSprintReport returns an empty report on malformed input
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/ai/presentation/helpers/ai_prompts.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_report.dart';

SprintReport _report() => const SprintReport(
  sprintName: 'Sprint 24',
  dateRange: 'Jun 10 - Jun 24',
  daysRemaining: 2,
  totalTickets: 47,
  pointsCommitted: 120,
  repoCount: 3,
  forecastLabel: 'Trending ~2d behind',
  forecastDetail: 'detail',
  behind: true,
  pointsDone: 82,
  estimatedTickets: 41,
  estimatedPoints: 110,
  unestimatedTickets: 6,
  burndown: Burndown(committedPoints: 120, totalDays: 10, todayDay: 8, snapshotsCaptured: 8, snapshotsTotal: 10),
);

void main() {
  test('prompt cites numbers and forbids fabrication', () {
    final p = buildSprintReportPrompt(_report());
    expect(p, contains('Sprint 24'));
    expect(p, contains('82'));
    expect(p.toLowerCase(), contains('do not invent'));
  });

  test('parseSprintReport reads a loose JSON object', () {
    const raw =
        'Here you go:\n{"executiveSummary":"Closed 82/120.","keyWins":["Shipped X"],'
        '"deliverables":[{"title":"X","status":"Complete","description":"d","impact":"i"}],'
        '"techHighlights":{"platform":["Redis"],"product":["Dash"]},"outcome":"Good."} done';
    final r = parseSprintReport(raw);
    expect(r.executiveSummary, 'Closed 82/120.');
    expect(r.keyWins.single, 'Shipped X');
    expect(r.deliverables.single.title, 'X');
    expect(r.techHighlights.product.single, 'Dash');
    expect(r.outcome, 'Good.');
  });

  test('parseSprintReport returns empty report on garbage', () {
    expect(parseSprintReport('no json here').executiveSummary, '');
    expect(parseSprintReport('no json here').keyWins, isEmpty);
  });
}
