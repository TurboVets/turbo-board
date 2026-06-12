import 'package:freezed_annotation/freezed_annotation.dart';

part 'pr_check.freezed.dart';

enum PrCheckState { success, pending, failure, neutral }

@freezed
sealed class PrCheck with _$PrCheck {
  const factory PrCheck({required String name, required PrCheckState state, String? summary}) = _PrCheck;
}
