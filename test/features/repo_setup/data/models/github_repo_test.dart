// test/features/repo_setup/data/models/github_repo_test.dart
//
// Test summary:
// - GithubRepo.fromJson maps full_name, owner.login, private, pushed_at, description.
// - pushedAt is null when absent; description is null when absent.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_repo.dart';

void main() {
  test('fromJson maps the GitHub repo payload', () {
    final repo = GithubRepo.fromJson(const {
      'name': 'platform',
      'full_name': 'TurboVets/platform',
      'owner': {'login': 'TurboVets'},
      'description': 'Backend',
      'private': true,
      'pushed_at': '2026-06-10T12:00:00Z',
    });

    expect(repo.name, 'platform');
    expect(repo.nameWithOwner, 'TurboVets/platform');
    expect(repo.owner, 'TurboVets');
    expect(repo.description, 'Backend');
    expect(repo.isPrivate, isTrue);
    expect(repo.pushedAt, DateTime.utc(2026, 6, 10, 12));
  });

  test('fromJson tolerates missing description and pushed_at', () {
    final repo = GithubRepo.fromJson(const {
      'name': 'docs',
      'full_name': 'TurboVets/docs',
      'owner': {'login': 'TurboVets'},
      'private': false,
    });

    expect(repo.description, isNull);
    expect(repo.pushedAt, isNull);
    expect(repo.isPrivate, isFalse);
  });
}
