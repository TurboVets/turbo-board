import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../lead_cockpit/data/models/cockpit_data.dart';

part 'board_data.freezed.dart';
part 'board_data.g.dart';

/// Whether a board item is a GitHub Issue or a Pull Request.
enum BoardItemType { issue, pullRequest }

/// PR CI rollup, derived from `commits.statusCheckRollup.state`.
enum PrCiState { passing, failing, pending, none }

/// PR review decision, derived from `reviewDecision`.
enum PrReviewState { approved, changesRequested, review, none }

/// One card on the board (issue or PR), already flattened from the GraphQL item.
@freezed
sealed class BoardCard with _$BoardCard {
  const BoardCard._();

  const factory BoardCard({
    required String id,
    required BoardItemType type,
    required String repo,
    required int number,
    required String title,
    @Default(false) bool isDraft,
    required IssueStatus status,
    IssuePriority? priority,
    int? points,
    int? subDone,
    int? subTotal,

    /// Days since last update once past the stuck threshold; null otherwise.
    int? staleDays,
    @Default(<String>[]) List<String> assignees,

    /// PR-only signals; null on issue cards.
    PrCiState? ciState,
    PrReviewState? reviewState,

    /// Repo owner login, used to build the PR-detail route on tap.
    String? owner,

    /// Iteration (sprint) title this item is assigned to, from the board's
    /// `Sprint` iteration field; null when the item is in no sprint.
    String? sprint,
  }) = _BoardCard;

  factory BoardCard.fromJson(Map<String, dynamic> json) => _$BoardCardFromJson(json);

  bool get isPr => type == BoardItemType.pullRequest;
  bool get hasSubIssues => (subTotal ?? 0) > 0;
  bool get isStale => staleDays != null;
}

/// Data-derived signal counts for one column — grounds the AI insight prompt.
@freezed
sealed class ColumnFacts with _$ColumnFacts {
  const ColumnFacts._();

  const factory ColumnFacts({
    @Default(0) int p0Unowned,
    @Default(0) int missingEstimate,
    @Default(0) int stuckCount,
    @Default(<int>[]) List<int> ciRedNumbers,
  }) = _ColumnFacts;

  bool get isEmpty => p0Unowned == 0 && missingEstimate == 0 && stuckCount == 0 && ciRedNumbers.isEmpty;
}

/// One Status column with its cards and derived facts.
@freezed
sealed class BoardColumn with _$BoardColumn {
  const BoardColumn._();

  const factory BoardColumn({
    required IssueStatus status,
    required String label,
    @Default(<BoardCard>[]) List<BoardCard> cards,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default(ColumnFacts()) ColumnFacts facts,
  }) = _BoardColumn;

  factory BoardColumn.fromJson(Map<String, dynamic> json) => _$BoardColumnFromJson(json);

  int get count => cards.length;
}

/// One iteration (sprint) from the board's `Sprint` iteration field.
@freezed
sealed class BoardSprint with _$BoardSprint {
  const BoardSprint._();

  const factory BoardSprint({
    required String title,
    required DateTime start,
    @Default(14) int durationDays,

    /// True for the iteration whose window contains "now".
    @Default(false) bool isCurrent,
  }) = _BoardSprint;

  factory BoardSprint.fromJson(Map<String, dynamic> json) => _$BoardSprintFromJson(json);

  DateTime get end => start.add(Duration(days: durationDays));
}

/// The sprint filter tabs shown above the board.
enum SprintTab { current, previous, next, all }

/// The whole board: title + ordered columns + the sprint catalog (oldest →
/// newest) used to drive the sprint filter tabs.
@freezed
sealed class ProjectBoardData with _$ProjectBoardData {
  const ProjectBoardData._();

  const factory ProjectBoardData({
    required String title,
    @Default(<BoardColumn>[]) List<BoardColumn> columns,
    @Default(<BoardSprint>[]) List<BoardSprint> sprints,
  }) = _ProjectBoardData;

  factory ProjectBoardData.fromJson(Map<String, dynamic> json) => _$ProjectBoardDataFromJson(json);

  bool get hasAnyCards => columns.any((c) => c.cards.isNotEmpty);
}

/// The five statuses the board renders, in column order. `cancelled` is hidden.
const boardColumnOrder = <IssueStatus>[
  IssueStatus.triage,
  IssueStatus.notStarted,
  IssueStatus.inProgress,
  IssueStatus.inReview,
  IssueStatus.done,
];
