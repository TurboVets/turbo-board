import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../data/models/pr_data.dart';
import '../../data/repositories/pr_inbox_repository.dart';

part 'pr_inbox_provider.g.dart';

@Riverpod(keepAlive: true)
PrInboxRepository prInboxRepository(Ref ref) {
  // Swapped for the real GitHub-backed implementation once integration lands.
  return const MockPrInboxRepository();
}

@riverpod
Future<List<PrData>> prInbox(Ref ref) async {
  final repo = ref.watch(prInboxRepositoryProvider);
  final result = await repo.fetchOpenPrs();

  return switch (result) {
    ResultSuccess(:final data) => data,
    ResultFailure(:final message) => throw Exception(message),
  };
}
