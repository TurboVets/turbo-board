import 'package:freezed_annotation/freezed_annotation.dart';

part 'pr_reviewer.freezed.dart';

enum PrReviewerState { approved, changesRequested, commented, pending }

@freezed
sealed class PrReviewer with _$PrReviewer {
  const factory PrReviewer({required String login, required PrReviewerState state}) = _PrReviewer;
}
