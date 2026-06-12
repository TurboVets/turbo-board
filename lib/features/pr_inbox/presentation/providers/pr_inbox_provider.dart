import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../../repo_setup/presentation/providers/watched_repos_provider.dart';
import '../../data/models/pr_data.dart';
import '../../data/repositories/pr_inbox_repository.dart';

part 'pr_inbox_provider.g.dart';

@Riverpod(keepAlive: true)
PrInboxRepository prInboxRepository(Ref ref) {
  final client = ref.watch(githubApiClientProvider);
  final watched = ref.watch(watchedReposProvider);
  return GithubPrInboxRepository(client, watched);
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
