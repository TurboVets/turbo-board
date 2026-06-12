import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../pr_inbox/data/models/pr_data.dart';
import '../../../pr_inbox/presentation/providers/pr_inbox_provider.dart';
import '../../../repo_setup/presentation/providers/auth_provider.dart';
import '../helpers/triage.dart';

part 'needs_attention_provider.g.dart';

/// Stale threshold in days (one of [staleThresholdOptions]). Default 7.
@Riverpod(keepAlive: true)
class StaleThreshold extends _$StaleThreshold {
  @override
  int build() => 7;

  void set(int days) {
    if (staleThresholdOptions.contains(days)) state = days;
  }
}

String? _currentLogin(Ref ref) => switch (ref.watch(authStateProvider)) {
  AuthAuthenticated(:final user) => user.login,
  _ => null,
};

/// PRs grouped into triage categories, sourced from the full open-PR set.
@riverpod
Future<Map<NeedsAttentionCategory, List<PrData>>> needsAttention(Ref ref) async {
  final prs = await ref.watch(prInboxProvider.future);
  final threshold = ref.watch(staleThresholdProvider);
  final myLogin = _currentLogin(ref);
  return categorize(prs, myLogin: myLogin, now: DateTime.now(), staleThresholdDays: threshold);
}

/// Deduplicated count of PRs needing attention — the nav rail badge value.
/// Resolves to 0 while the inbox is loading or errored.
@riverpod
int needsAttentionBadge(Ref ref) {
  final prs = ref.watch(prInboxProvider).asData?.value ?? const [];
  final threshold = ref.watch(staleThresholdProvider);
  final myLogin = _currentLogin(ref);
  return needsAttentionCount(prs, myLogin: myLogin, now: DateTime.now(), staleThresholdDays: threshold);
}
