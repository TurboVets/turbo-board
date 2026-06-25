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

/// A pickable GitHub Projects v2 board (`owner` is a user or org login).
@freezed
sealed class ProjectRef with _$ProjectRef {
  const ProjectRef._();

  const factory ProjectRef({required String owner, required int number, required String title}) = _ProjectRef;

  factory ProjectRef.fromJson(Map<String, dynamic> json) => _$ProjectRefFromJson(json);

  /// Stable identity for de-duping / selection comparison.
  String get key => '$owner#$number';
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
/// [url] is the GitHub issue page, opened when the row is tapped.
@freezed
sealed class MemberItem with _$MemberItem {
  const MemberItem._();

  const factory MemberItem({
    required String title,
    required IssueStatus status,
    String? url,

    /// Days the item has sat in its current status (only meaningful when [stuck]).
    @Default(0) int ageDays,

    /// True when the item has aged past the stuck threshold — drives the red dot
    /// and the `Nd` age tag on the row.
    @Default(false) bool stuck,

    /// Sub-issue rollup (`subIssuesSummary`); shown as a `subDone/subTotal` chip.
    int? subDone,
    int? subTotal,
  }) = _MemberItem;

  factory MemberItem.fromJson(Map<String, dynamic> json) => _$MemberItemFromJson(json);

  /// Whether this item has sub-issues worth showing a progress chip for.
  bool get hasSubIssues => (subTotal ?? 0) > 0;
}

/// Per-assignee load card: counts, story-point load, and the member's top items.
@freezed
sealed class TeamMemberLoad with _$TeamMemberLoad {
  const TeamMemberLoad._();

  const factory TeamMemberLoad({
    required String handle,
    required int wip,
    required int inReview,
    required int stuck,

    /// Items this member has closed in the current sprint (throughput).
    @Default(0) int done,

    /// Sum of `complexity` (story points) over the member's open items — the
    /// effort-based load measure the gauge is driven by.
    @Default(0) int points,

    /// Open items carrying no complexity estimate.
    @Default(0) int unestimated,

    /// Open P0/P1 items this member is carrying.
    @Default(0) int highPriority,
    @Default(<MemberItem>[]) List<MemberItem> items,
  }) = _TeamMemberLoad;

  factory TeamMemberLoad.fromJson(Map<String, dynamic> json) => _$TeamMemberLoadFromJson(json);

  /// Light load with headroom to take a handoff — gray AVAILABLE badge.
  bool get isAvailable => points <= 12 && wip < 5;
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

    /// The GitHub issue page, opened when the row is tapped.
    String? url,
  }) = _StuckIssue;

  factory StuckIssue.fromJson(Map<String, dynamic> json) => _$StuckIssueFromJson(json);
}

/// A single ticket touched on a given sprint day — closed (done) or created
/// (opened). [number] is the display tag (`#412`); [url] opens the GitHub page.
/// [assignee] is the GitHub login of the primary assignee — drives the row's
/// avatar; empty when unassigned.
@freezed
sealed class FlowTicket with _$FlowTicket {
  const factory FlowTicket({
    required String number,
    required String title,
    required String repo,
    @Default('') String assignee,
    String? url,
  }) = _FlowTicket;

  factory FlowTicket.fromJson(Map<String, dynamic> json) => _$FlowTicketFromJson(json);
}

/// One day in the sprint with its throughput (closed) and inflow (created)
/// counts plus the tickets behind each, shown as a tile + a detail popup.
@freezed
sealed class FlowDay with _$FlowDay {
  const FlowDay._();

  const factory FlowDay({
    required DateTime date,
    @Default(0) int done,
    @Default(0) int opened,
    @Default(<FlowTicket>[]) List<FlowTicket> doneTickets,
    @Default(<FlowTicket>[]) List<FlowTicket> openedTickets,
  }) = _FlowDay;

  factory FlowDay.fromJson(Map<String, dynamic> json) => _$FlowDayFromJson(json);

  bool get hasActivity => done > 0 || opened > 0;
}

/// Per-day sprint activity over the iteration window — drives the burnup chart
/// (cumulative done vs cumulative scope) and the daily-activity tile strip.
/// Sourced from each board item's `createdAt` / `closedAt` (no event-walk).
@freezed
sealed class SprintFlow with _$SprintFlow {
  const SprintFlow._();

  const factory SprintFlow({required DateTime start, required DateTime end, @Default(<FlowDay>[]) List<FlowDay> days}) =
      _SprintFlow;

  factory SprintFlow.fromJson(Map<String, dynamic> json) => _$SprintFlowFromJson(json);

  bool get isEmpty => days.every((d) => !d.hasActivity);
}

/// Everything the Lead Cockpit screen renders, fetched as one unit.
@freezed
sealed class CockpitData with _$CockpitData {
  const factory CockpitData({
    required SprintHealth sprint,
    required List<TeamMemberLoad> team,
    required List<StuckIssue> stuck,
    required SprintFlow flow,
  }) = _CockpitData;

  factory CockpitData.fromJson(Map<String, dynamic> json) => _$CockpitDataFromJson(json);
}
