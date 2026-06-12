import 'package:freezed_annotation/freezed_annotation.dart';

part 'sprint_report.freezed.dart';
part 'sprint_report.g.dart';

/// The status buckets shown in "Points by status" (open work only — Cancelled
/// is excluded from a sprint report).
enum ReportStatusKind { done, inProgress, inReview, notStarted }

/// One slice of the points-by-status breakdown.
@freezed
sealed class StatusSlice with _$StatusSlice {
  const factory StatusSlice({
    required ReportStatusKind kind,
    required String label,
    required int tickets,
    required int points,
  }) = _StatusSlice;

  factory StatusSlice.fromJson(Map<String, dynamic> json) => _$StatusSliceFromJson(json);
}

/// Per-assignee point split: done / in-progress / remaining.
@freezed
sealed class AssigneePoints with _$AssigneePoints {
  const AssigneePoints._();

  const factory AssigneePoints({
    required String handle,
    required int done,
    required int inProgress,
    required int remaining,
  }) = _AssigneePoints;

  factory AssigneePoints.fromJson(Map<String, dynamic> json) => _$AssigneePointsFromJson(json);

  int get total => done + inProgress + remaining;
  int get open => inProgress + remaining;
}

/// Epic rollup: sub-issue progress + point progress.
@freezed
sealed class EpicProgress with _$EpicProgress {
  const EpicProgress._();

  const factory EpicProgress({
    required String title,
    required int subsDone,
    required int subsTotal,
    required int pointsDone,
    required int pointsTotal,
  }) = _EpicProgress;

  factory EpicProgress.fromJson(Map<String, dynamic> json) => _$EpicProgressFromJson(json);

  int get percent => subsTotal == 0 ? 0 : (subsDone / subsTotal * 100).round();
}

/// Burndown data. Real `actualRemaining` accrues from daily board snapshots
/// (see docs/V2-ISSUES-SCOPE.md); until then only the ideal line + today marker
/// are live and the chart shows the "history accruing" treatment.
@freezed
sealed class Burndown with _$Burndown {
  const Burndown._();

  const factory Burndown({
    required int committedPoints,
    required int totalDays,
    required int todayDay,
    required int snapshotsCaptured,
    required int snapshotsTotal,

    /// Remaining points at the end of each day, index 0..todayDay.
    @Default(<int>[]) List<int> actualRemaining,
  }) = _Burndown;

  factory Burndown.fromJson(Map<String, dynamic> json) => _$BurndownFromJson(json);

  int get pointsLeft => actualRemaining.isEmpty ? committedPoints : actualRemaining.last;
}

/// Everything the Sprint Report screen renders, fetched as one unit.
@freezed
sealed class SprintReport with _$SprintReport {
  const SprintReport._();

  const factory SprintReport({
    required String sprintName,
    required String dateRange,
    required int daysRemaining,
    required int totalTickets,
    required int pointsCommitted,
    required int repoCount,

    /// Short forecast chip ("Trending ~2D behind") + the hover math + whether
    /// it is behind (orange) vs on/ahead (green).
    required String forecastLabel,
    required String forecastDetail,
    @Default(true) bool behind,

    required int pointsDone,
    @Default(<StatusSlice>[]) List<StatusSlice> status,

    required int estimatedTickets,
    required int estimatedPoints,
    required int unestimatedTickets,

    @Default(<AssigneePoints>[]) List<AssigneePoints> people,
    @Default(<EpicProgress>[]) List<EpicProgress> epics,
    required Burndown burndown,
  }) = _SprintReport;

  factory SprintReport.fromJson(Map<String, dynamic> json) => _$SprintReportFromJson(json);

  int get percentDone => pointsCommitted == 0 ? 0 : (pointsDone / pointsCommitted * 100).round();
  int get unestimatedPercent => totalTickets == 0 ? 0 : (unestimatedTickets / totalTickets * 100).round();
}
