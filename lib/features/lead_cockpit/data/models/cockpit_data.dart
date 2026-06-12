import 'package:freezed_annotation/freezed_annotation.dart';

part 'cockpit_data.freezed.dart';
part 'cockpit_data.g.dart';

/// Status of a GitHub Projects v2 board item. JSON values match the board's
/// single-select option names so the future GraphQL repository can deserialize
/// `fieldValues` directly.
enum IssueStatus {
  @JsonValue('Not Started')
  notStarted,
  @JsonValue('In Progress')
  inProgress,
  @JsonValue('In Review')
  inReview,
  @JsonValue('Triage')
  triage,
  @JsonValue('Done')
  done,
  @JsonValue('Cancelled')
  cancelled,
}

/// Board Priority single-select.
enum IssuePriority {
  @JsonValue('P0')
  p0,
  @JsonValue('P1')
  p1,
  @JsonValue('P2')
  p2,
  @JsonValue('P3')
  p3,
}

/// Sprint-wide health snapshot for the cockpit header strip.
@freezed
sealed class SprintHealth with _$SprintHealth {
  const SprintHealth._();

  const factory SprintHealth({
    required String name,
    required int daysRemaining,
    required String endLabel,
    required int totalIssues,
    required int repoCount,
    required int done,
    required int inProgress,
    required int inReview,
    required int notStarted,
    required int atRisk,
    required int unestimated,
  }) = _SprintHealth;

  factory SprintHealth.fromJson(Map<String, dynamic> json) => _$SprintHealthFromJson(json);
}

/// One ticket title + its status, shown under a team member's card.
@freezed
sealed class MemberItem with _$MemberItem {
  const factory MemberItem({required String title, required IssueStatus status}) = _MemberItem;

  factory MemberItem.fromJson(Map<String, dynamic> json) => _$MemberItemFromJson(json);
}

/// Per-assignee load card: WIP / in-review / stuck counts and a 0–100 load gauge.
@freezed
sealed class TeamMemberLoad with _$TeamMemberLoad {
  const TeamMemberLoad._();

  const factory TeamMemberLoad({
    required String handle,
    required int wip,
    required int inReview,
    required int stuck,
    required int loadPercent,
    @Default(<MemberItem>[]) List<MemberItem> items,
  }) = _TeamMemberLoad;

  factory TeamMemberLoad.fromJson(Map<String, dynamic> json) => _$TeamMemberLoadFromJson(json);

  /// Carrying roughly twice the team median — flagged red in the UI.
  bool get isOverloaded => loadPercent >= 90;
}

/// A board item that has sat too long in its current status.
@freezed
sealed class StuckIssue with _$StuckIssue {
  const StuckIssue._();

  const factory StuckIssue({
    required String title,
    required String repo,
    required String assignee,
    required IssuePriority priority,
    required IssueStatus status,
    required int ageDays,
    required String prLabel,

    /// True when the age is past the hard threshold (red) vs merely aging (orange).
    @Default(false) bool critical,
  }) = _StuckIssue;

  factory StuckIssue.fromJson(Map<String, dynamic> json) => _$StuckIssueFromJson(json);
}

/// Everything the Lead Cockpit screen renders, fetched as one unit.
@freezed
sealed class CockpitData with _$CockpitData {
  const factory CockpitData({
    required SprintHealth sprint,
    required List<TeamMemberLoad> team,
    required List<StuckIssue> stuck,
  }) = _CockpitData;

  factory CockpitData.fromJson(Map<String, dynamic> json) => _$CockpitDataFromJson(json);
}
