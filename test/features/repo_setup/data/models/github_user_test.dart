// test/features/repo_setup/data/models/github_user_test.dart
//
// Test summary:
// - GithubUser.fromJson maps GitHub /user payload (login, avatar_url, name).
// - name is null when absent.
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/repo_setup/data/models/github_user.dart';

void main() {
  test('fromJson maps login, avatarUrl and name', () {
    final user = GithubUser.fromJson(const {
      'login': 'octocat',
      'avatar_url': 'https://example.com/a.png',
      'name': 'The Octocat',
    });

    expect(user.login, 'octocat');
    expect(user.avatarUrl, 'https://example.com/a.png');
    expect(user.name, 'The Octocat');
  });

  test('fromJson tolerates a missing name', () {
    final user = GithubUser.fromJson(const {'login': 'octocat', 'avatar_url': 'https://example.com/a.png'});

    expect(user.name, isNull);
  });
}
