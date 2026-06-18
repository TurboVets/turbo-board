// lib/features/issue_detail/presentation/providers/issue_detail_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../data/models/issue_detail.dart';
import '../../data/repositories/issue_detail_repository.dart';

part 'issue_detail_provider.g.dart';

@Riverpod(keepAlive: true)
IssueDetailRepository issueDetailRepository(Ref ref) => GithubIssueDetailRepository(ref.watch(githubApiClientProvider));

@riverpod
Future<IssueDetail> issueDetail(Ref ref, {required String owner, required String repo, required int number}) async {
  final result = await ref.watch(issueDetailRepositoryProvider).fetchDetail(owner, repo, number);
  return switch (result) {
    ResultSuccess(:final data) => data,
    ResultFailure(:final message) => throw Exception(message),
  };
}
