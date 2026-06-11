// Test summary:
// - MockPrInboxRepository returns a successful Result with a non-empty PR list
// - Every sample PR has a valid slug ("owner/name#number")
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/pr_inbox/data/repositories/pr_inbox_repository.dart';
import 'package:turbo_core/core.dart';

void main() {
  group('MockPrInboxRepository', () {
    test('should return success with a non-empty list when fetching open PRs', () async {
      // Arrange
      const repo = MockPrInboxRepository();

      // Act
      final result = await repo.fetchOpenPrs();

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.value, isNotEmpty);
    });

    test('should expose a valid slug for every PR', () async {
      // Arrange
      const repo = MockPrInboxRepository();

      // Act
      final result = await repo.fetchOpenPrs();

      // Assert
      for (final pr in result.value) {
        expect(pr.slug, matches(RegExp(r'^[\w-]+/[\w.-]+#\d+$')));
      }
    });
  });
}
