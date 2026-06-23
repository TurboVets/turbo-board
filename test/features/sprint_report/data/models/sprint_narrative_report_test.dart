// Test summary:
// - fromJson builds a full report from complete JSON
// - fromJson defaults missing lists/strings instead of throwing
// - copyWith replaces overallStatus
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/sprint_report/data/models/sprint_narrative_report.dart';

void main() {
  test('fromJson builds a full report', () {
    final r = SprintNarrativeReport.fromJson({
      'executiveSummary': 'Closed 82/120 points.',
      'keyWins': ['Released Checkout v2'],
      'overallStatus': 'onTrack',
      'deliverables': [
        {'title': 'Checkout v2', 'status': 'Complete', 'description': 'Dashboard', 'impact': 'Self-service'},
      ],
      'techHighlights': {
        'platform': ['Redis caching'],
        'product': ['Analytics dashboard'],
      },
      'challenges': ['Security review pending'],
      'mitigations': ['Scheduled next sprint'],
      'learnings': ['Caching helped'],
      'nextPriorities': ['AI workflow MVP'],
      'recognition': ['@ko migration'],
      'outcome': 'Successful sprint.',
    });
    expect(r.executiveSummary, 'Closed 82/120 points.');
    expect(r.keyWins.single, 'Released Checkout v2');
    expect(r.deliverables.single.impact, 'Self-service');
    expect(r.techHighlights.platform.single, 'Redis caching');
    expect(r.outcome, 'Successful sprint.');
  });

  test('fromJson tolerates missing fields', () {
    final r = SprintNarrativeReport.fromJson({'executiveSummary': 'x'});
    expect(r.keyWins, isEmpty);
    expect(r.deliverables, isEmpty);
    expect(r.techHighlights.platform, isEmpty);
    expect(r.outcome, '');
  });

  test('copyWith replaces overallStatus', () {
    final r = SprintNarrativeReport.fromJson({'executiveSummary': 'x'});
    expect(r.copyWith(overallStatus: SprintHealth.behind).overallStatus, SprintHealth.behind);
  });
}
