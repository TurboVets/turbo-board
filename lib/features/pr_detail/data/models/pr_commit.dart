import 'package:freezed_annotation/freezed_annotation.dart';

part 'pr_commit.freezed.dart';

@freezed
sealed class PrCommit with _$PrCommit {
  const factory PrCommit({required String abbreviatedOid, required String messageHeadline, DateTime? committedDate}) =
      _PrCommit;
}
