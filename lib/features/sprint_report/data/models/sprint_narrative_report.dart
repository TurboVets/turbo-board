import 'package:freezed_annotation/freezed_annotation.dart';

part 'sprint_narrative_report.freezed.dart';
part 'sprint_narrative_report.g.dart';

/// Overall sprint health. Set deterministically from the forecast after the AI
/// call — the model never trusts the AI for this value.
enum SprintOutlook { onTrack, atRisk, behind }

@freezed
sealed class Deliverable with _$Deliverable {
  const factory Deliverable({
    @Default('') String title,
    @Default('') String status,
    @Default('') String description,
    @Default('') String impact,
  }) = _Deliverable;

  factory Deliverable.fromJson(Map<String, dynamic> json) => _$DeliverableFromJson(json);
}

@freezed
sealed class TechHighlights with _$TechHighlights {
  const factory TechHighlights({
    @Default(<String>[]) List<String> platform,
    @Default(<String>[]) List<String> product,
  }) = _TechHighlights;

  factory TechHighlights.fromJson(Map<String, dynamic> json) => _$TechHighlightsFromJson(json);
}

/// The structured narrative the AI produces and the export builders consume.
/// Carries NO metric numbers — metrics are computed (REAL) or user-entered (YOU).
@freezed
sealed class SprintNarrativeReport with _$SprintNarrativeReport {
  const factory SprintNarrativeReport({
    @Default('') String executiveSummary,
    @Default(<String>[]) List<String> keyWins,
    @Default(SprintOutlook.onTrack) SprintOutlook overallStatus,
    @Default(<Deliverable>[]) List<Deliverable> deliverables,
    @Default(TechHighlights()) TechHighlights techHighlights,
    @Default(<String>[]) List<String> challenges,
    @Default(<String>[]) List<String> mitigations,
    @Default(<String>[]) List<String> learnings,
    @Default(<String>[]) List<String> nextPriorities,
    @Default(<String>[]) List<String> recognition,
    @Default('') String outcome,
  }) = _SprintNarrativeReport;

  factory SprintNarrativeReport.fromJson(Map<String, dynamic> json) => _$SprintNarrativeReportFromJson(json);
}
