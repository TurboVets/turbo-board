import 'package:freezed_annotation/freezed_annotation.dart';

import 'pr_reviewer.dart';

part 'pr_timeline_event.freezed.dart';

/// The visual vocabulary of the activity timeline (mirrors `TurboBoard.dc.html`).
///
/// - [comment] and [reviewComment] render as **comment cards** (avatar node +
///   header + markdown body). [reviewComment] additionally shows a review badge
///   driven by [PrTimelineEvent.reviewState].
/// - Everything else renders as a **compact event row** (a node icon + a single
///   line of text). The body is empty; the line is composed from
///   [PrTimelineEvent.author] and the optional [PrTimelineEvent.detail]
///   (reviewer login, label name, commit count, new title, …).
enum PrEventKind {
  opened,
  comment,
  reviewComment,
  approved,
  changesRequested,
  commitsPushed,
  reviewRequested,
  reviewRequestRemoved,
  labeled,
  forcePushed,
  merged,
  closed,
  reopened,
  readyForReview,
  renamed,
}

@freezed
sealed class PrTimelineEvent with _$PrTimelineEvent {
  const factory PrTimelineEvent({
    required String author,
    required DateTime createdAt,
    required PrEventKind kind,
    @Default('') String bodyMarkdown,

    /// Extra context for compact event rows: the reviewer login (review
    /// requested/removed), label name (labeled), commit count (commits pushed),
    /// or the new title (renamed). Unused by comment cards.
    String? detail,
    PrReviewerState? reviewState,
  }) = _PrTimelineEvent;
}
