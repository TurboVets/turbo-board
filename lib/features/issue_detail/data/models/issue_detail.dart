// lib/features/issue_detail/data/models/issue_detail.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../lead_cockpit/data/models/cockpit_data.dart';
import '../../../pr_inbox/data/models/pr_data.dart';

part 'issue_detail.freezed.dart';
part 'issue_detail.g.dart';

enum IssueState { open, closed }

/// Merge state of a linked PR, for the third dot in the Linked PRs card.
enum PrLinkMergeState { open, merged, closed, draft }

/// Kinds of activity rendered in the issue timeline.
enum IssueEventKind { opened, comment, closed, reopened, labeled, assigned, unassigned, crossReferenced, renamed }

@freezed
sealed class IssueLabel with _$IssueLabel {
  const factory IssueLabel({required String name, required String colorHex}) = _IssueLabel;
  factory IssueLabel.fromJson(Map<String, dynamic> json) => _$IssueLabelFromJson(json);
}

/// A reference to another issue (parent epic / relationship row).
@freezed
sealed class IssueRef with _$IssueRef {
  const factory IssueRef({
    required String repo, // "owner/name"
    required int number,
    required String title,
    IssueStatus? status,
  }) = _IssueRef;
  factory IssueRef.fromJson(Map<String, dynamic> json) => _$IssueRefFromJson(json);
}

@freezed
sealed class SubIssue with _$SubIssue {
  const factory SubIssue({
    required int number,
    required String title,
    required IssueStatus status,
    @Default(false) bool done,
    String? assignee,
  }) = _SubIssue;
  factory SubIssue.fromJson(Map<String, dynamic> json) => _$SubIssueFromJson(json);
}

@freezed
sealed class LinkedPr with _$LinkedPr {
  const factory LinkedPr({
    required String owner,
    required String repo,
    required int number,
    required String title,
    @Default(false) bool isDraft,
    required PrCiState ciState,
    required PrReviewState reviewState,
    @Default(PrLinkMergeState.open) PrLinkMergeState mergeState,
  }) = _LinkedPr;
  factory LinkedPr.fromJson(Map<String, dynamic> json) => _$LinkedPrFromJson(json);
}

@freezed
sealed class IssueTimelineEvent with _$IssueTimelineEvent {
  const factory IssueTimelineEvent({
    required String author,
    required DateTime createdAt,
    required IssueEventKind kind,
    @Default('') String bodyMarkdown,
    String? detail,
  }) = _IssueTimelineEvent;
  factory IssueTimelineEvent.fromJson(Map<String, dynamic> json) => _$IssueTimelineEventFromJson(json);
}

@freezed
sealed class IssueDetail with _$IssueDetail {
  const IssueDetail._();

  const factory IssueDetail({
    required String repo, // "owner/name"
    String? id, // GraphQL node id — needed for mutations
    required int number,
    required String title,
    String? url,
    required IssueState state,
    required String author,
    DateTime? createdAt,
    @Default('') String bodyMarkdown,
    @Default(0) int commentCount,
    @Default(<String>[]) List<String> assignees,
    @Default(<IssueLabel>[]) List<IssueLabel> labels,
    @Default(<String>[]) List<String> participants,
    IssueStatus? status,
    IssuePriority? priority,
    String? sprint,
    int? points,
    String? milestone,
    IssueRef? parent,
    @Default(<SubIssue>[]) List<SubIssue> subIssues,
    @Default(<LinkedPr>[]) List<LinkedPr> linkedPrs,
    @Default(<IssueTimelineEvent>[]) List<IssueTimelineEvent> timeline,
    @Default(false) bool viewerCanUpdate,
    String? repoDefaultBranchOid,

    // ProjectV2 Status-field write handles. Present only when the issue is on a
    // project and the viewer can update it.
    String? projectId,
    String? projectItemId,
    String? statusFieldId,
    @Default(<IssueStatusOption>[]) List<IssueStatusOption> statusOptions,
  }) = _IssueDetail;

  factory IssueDetail.fromJson(Map<String, dynamic> json) => _$IssueDetailFromJson(json);

  String get slug => '$repo#$number';
  int get subDone => subIssues.where((s) => s.done).length;
  int get subTotal => subIssues.length;
  bool get hasSubIssues => subTotal > 0;
  bool get isClosed => state == IssueState.closed;

  /// The viewer can change the Status field from the drawer.
  bool get canUpdateStatus =>
      viewerCanUpdate &&
      projectId != null &&
      projectItemId != null &&
      statusFieldId != null &&
      statusOptions.isNotEmpty;
}

/// One selectable value of the project's Status single-select field. [id] is the
/// option id used by the update mutation; [status] is its mapped enum (for the
/// dot color), or null when the option name doesn't map to a known status.
@freezed
sealed class IssueStatusOption with _$IssueStatusOption {
  const factory IssueStatusOption({required String id, required String name, IssueStatus? status}) = _IssueStatusOption;
  factory IssueStatusOption.fromJson(Map<String, dynamic> json) => _$IssueStatusOptionFromJson(json);
}
