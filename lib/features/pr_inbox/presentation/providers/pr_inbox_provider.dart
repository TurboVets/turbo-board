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
  return result.when(
    success: (data) {
      // Guard: the autodispose provider may already be torn down after the
      // await if nothing is listening (e.g. a one-shot `.future` read in tests).
      if (ref.mounted) ref.keepAlive();
      return data;
    },
    failure: (message, stackTrace) => throw Exception(message),
  );
}

/// Open-PR count per repo slug, derived from the current inbox data. Drives the
/// count chips in the nav rail's watched-repos section. Empty map while the
/// board is loading or errored.
@riverpod
Map<String, int> prCountsByRepo(Ref ref) {
  final prs = ref.watch(prInboxProvider).asData?.value ?? const <PrData>[];
  final counts = <String, int>{};
  for (final pr in prs) {
    counts[pr.repo] = (counts[pr.repo] ?? 0) + 1;
  }
  return counts;
}
