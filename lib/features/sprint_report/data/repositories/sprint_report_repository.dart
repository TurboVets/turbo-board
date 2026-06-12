import 'dart:developer';

import 'package:turbo_core/core.dart';

import '../models/sprint_report.dart';

/// Data access for the Sprint Report (GitHub Projects v2 board rollup).
///
/// v0 ships a mock seeded with the design's sample sprint so the screen can be
/// built and tested. The live implementation rolls up the same `projectV2`
/// board query the Lead Cockpit uses (points come from the Complexity field);
/// the burndown's `actualRemaining` series fills in once the snapshot history
/// lands — see `docs/V2-ISSUES-SCOPE.md`.
abstract class SprintReportRepository {
  Future<Result<SprintReport>> fetchReport();
}

class MockSprintReportRepository implements SprintReportRepository {
  const MockSprintReportRepository();

  @override
  Future<Result<SprintReport>> fetchReport() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return Result.success(_sample);
    } catch (e, stackTrace) {
      log('Failed to load the sprint report', error: e, stackTrace: stackTrace);
      return Result.failure('Failed to load the sprint report', stackTrace);
    }
  }
}

const _sample = SprintReport(
  sprintName: 'Sprint 24 · Mobile Space',
  dateRange: 'Jun 3 – Jun 17',
  daysRemaining: 6,
  totalTickets: 145,
  pointsCommitted: 168,
  repoCount: 3,
  forecastLabel: 'Trending ~2D behind',
  forecastDetail: '74 pts done vs 96 ideal at day 8 of 14 — gap of 22 pts ≈ 2.4 days at the current rate',
  behind: true,
  pointsDone: 74,
  status: [
    StatusSlice(kind: ReportStatusKind.done, label: 'Done', tickets: 58, points: 74),
    StatusSlice(kind: ReportStatusKind.inProgress, label: 'In progress', tickets: 31, points: 39),
    StatusSlice(kind: ReportStatusKind.inReview, label: 'In review', tickets: 17, points: 22),
    StatusSlice(kind: ReportStatusKind.notStarted, label: 'Not started', tickets: 27, points: 33),
  ],
  estimatedTickets: 133,
  estimatedPoints: 168,
  unestimatedTickets: 12,
  people: [
    AssigneePoints(handle: 'tromero-tv', done: 12, inProgress: 16, remaining: 10),
    AssigneePoints(handle: 'snguyen-tv', done: 14, inProgress: 8, remaining: 8),
    AssigneePoints(handle: 'apatel-tv', done: 16, inProgress: 6, remaining: 5),
    AssigneePoints(handle: 'mkim-tv', done: 21, inProgress: 5, remaining: 4),
    AssigneePoints(handle: 'lbarros-tv', done: 8, inProgress: 3, remaining: 1),
  ],
  epics: [
    EpicProgress(title: 'Recruit application flow v2', subsDone: 8, subsTotal: 12, pointsDone: 34, pointsTotal: 52),
    EpicProgress(
      title: 'Shared component library migration',
      subsDone: 11,
      subsTotal: 14,
      pointsDone: 30,
      pointsTotal: 38,
    ),
    EpicProgress(title: 'Deeplink & cold-start hardening', subsDone: 3, subsTotal: 8, pointsDone: 10, pointsTotal: 26),
    EpicProgress(title: 'Offline-first submissions', subsDone: 1, subsTotal: 6, pointsDone: 6, pointsTotal: 24),
  ],
  burndown: Burndown(
    committedPoints: 168,
    totalDays: 14,
    todayDay: 8,
    snapshotsCaptured: 2,
    snapshotsTotal: 14,
    actualRemaining: [168, 168, 160, 148, 142, 128, 120, 104, 94],
  ),
);
