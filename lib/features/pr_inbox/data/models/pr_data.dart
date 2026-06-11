import 'package:freezed_annotation/freezed_annotation.dart';

part 'pr_data.freezed.dart';
part 'pr_data.g.dart';

enum PrReviewState {
  @JsonValue('review_required')
  needsReview,
  @JsonValue('changes_requested')
  changesRequested,
  @JsonValue('approved')
  approved,
  @JsonValue('waiting_on_author')
  waitingOnAuthor,
}

enum PrCiState {
  @JsonValue('passing')
  passing,
  @JsonValue('pending')
  pending,
  @JsonValue('failing')
  failing,
}

@freezed
sealed class PrData with _$PrData {
  const PrData._();

  const factory PrData({
    /// "owner/name"
    required String repo,
    required int number,
    required String title,
    String? body,
    required String author,
    @Default(false) bool isDraft,
    required PrReviewState reviewState,
    required PrCiState ciState,
    required DateTime updatedAt,
    String? htmlUrl,
  }) = _PrData;

  factory PrData.fromJson(Map<String, dynamic> json) => _$PrDataFromJson(json);

  String get slug => '$repo#$number';
}
