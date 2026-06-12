import 'package:freezed_annotation/freezed_annotation.dart';

part 'sprint_snapshot.freezed.dart';
part 'sprint_snapshot.g.dart';

/// One captured data point for the burndown: how many points remained at the
/// end of sprint [day] (0-based day index within the iteration). Captured
/// locally on each report view — see [SprintSnapshotStore].
@freezed
sealed class SprintSnapshot with _$SprintSnapshot {
  const factory SprintSnapshot({
    required int day,
    required int remaining,

    /// ISO-8601 calendar date the point was captured, for auditing.
    required String date,
  }) = _SprintSnapshot;

  factory SprintSnapshot.fromJson(Map<String, dynamic> json) => _$SprintSnapshotFromJson(json);
}
