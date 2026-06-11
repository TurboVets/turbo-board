// Test summary:
// - prInboxProvider returns PR list when the repository succeeds
// - prInboxProvider throws when the repository fails
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/data/repositories/pr_inbox_repository.dart';
import 'package:turbo_board/features/pr_inbox/presentation/providers/pr_inbox_provider.dart';
import 'package:turbo_core/core.dart';

class _FailingRepo implements PrInboxRepository {
  @override
  Future<Result<List<PrData>>> fetchOpenPrs() async {
    return Result.failure('boom', StackTrace.current);
  }
}

void main() {
  late ProviderContainer container;

  tearDown(() => container.dispose());

  group('prInboxProvider', () {
    test('should return PRs when repository succeeds', () async {
      // Arrange
      container = ProviderContainer(
        overrides: [
          prInboxRepositoryProvider.overrideWithValue(const MockPrInboxRepository()),
        ],
      );

      // Act
      final prs = await container.read(prInboxProvider.future);

      // Assert
      expect(prs, isNotEmpty);
    });

    test('should throw when repository fails', () async {
      // Arrange
      container = ProviderContainer(
        overrides: [
          prInboxRepositoryProvider.overrideWithValue(_FailingRepo()),
        ],
      );

      // Act & Assert
      expect(
        () => container.read(prInboxProvider.future),
        throwsException,
      );
    });
  });
}
