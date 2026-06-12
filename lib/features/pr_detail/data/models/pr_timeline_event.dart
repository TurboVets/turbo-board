import 'package:freezed_annotation/freezed_annotation.dart';

import 'pr_reviewer.dart';

part 'pr_timeline_event.freezed.dart';

enum PrEventKind { comment, review }

@freezed
sealed class PrTimelineEvent with _$PrTimelineEvent {
  const factory PrTimelineEvent({
    required String author,
    required String bodyMarkdown,
    required DateTime createdAt,
    required PrEventKind kind,
    PrReviewerState? reviewState,
  }) = _PrTimelineEvent;
}
