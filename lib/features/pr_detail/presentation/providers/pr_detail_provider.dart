// lib/features/pr_detail/presentation/providers/pr_detail_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:turbo_core/core.dart';

import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../../data/models/pr_detail.dart';
import '../../data/repositories/pr_detail_repository.dart';

part 'pr_detail_provider.g.dart';

@Riverpod(keepAlive: true)
PrDetailRepository prDetailRepository(Ref ref) => GithubPrDetailRepository(ref.watch(githubApiClientProvider));

@riverpod
Future<PrDetail> prDetail(Ref ref, {required String owner, required String name, required int number}) async {
  final result = await ref.watch(prDetailRepositoryProvider).fetchDetail(owner, name, number);
  return switch (result) {
    ResultSuccess(:final data) => data,
    ResultFailure(:final message) => throw Exception(message),
  };
}
