// lib/features/repo_setup/data/models/github_repo.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'github_repo.freezed.dart';
part 'github_repo.g.dart';

String _ownerFromJson(Map<String, dynamic> owner) => owner['login'] as String;

@freezed
sealed class GithubRepo with _$GithubRepo {
  const factory GithubRepo({
    required String name,
    @JsonKey(name: 'full_name') required String nameWithOwner,
    @JsonKey(name: 'owner', fromJson: _ownerFromJson) required String owner,
    String? description,
    @JsonKey(name: 'private') @Default(false) bool isPrivate,
    @JsonKey(name: 'pushed_at') DateTime? pushedAt,
  }) = _GithubRepo;

  factory GithubRepo.fromJson(Map<String, dynamic> json) => _$GithubRepoFromJson(json);
}
