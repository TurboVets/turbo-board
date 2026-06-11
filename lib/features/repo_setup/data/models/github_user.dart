import 'package:freezed_annotation/freezed_annotation.dart';

part 'github_user.freezed.dart';
part 'github_user.g.dart';

@freezed
sealed class GithubUser with _$GithubUser {
  const factory GithubUser({
    required String login,
    @JsonKey(name: 'avatar_url') required String avatarUrl,
    String? name,
  }) = _GithubUser;

  factory GithubUser.fromJson(Map<String, dynamic> json) => _$GithubUserFromJson(json);
}
