import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../pr_detail/presentation/providers/pr_detail_provider.dart';
import '../../../pr_inbox/presentation/providers/pr_inbox_provider.dart';
import '../../../projects_board/presentation/providers/projects_board_provider.dart';
import '../../../repo_setup/presentation/providers/watched_repos_provider.dart';
import '../../../sprint_report/presentation/providers/sprint_report_provider.dart';
import '../../data/models/repo_event.dart';
import '../../data/repositories/realtime_repository.dart';

part 'realtime_provider.g.dart';

/// Connection state of the realtime relay. `auto_refresh` widens its polling
/// interval while [connected].
enum RealtimeStatus { disabled, connecting, connected, error }

const _debounce = Duration(seconds: 3);

@riverpod
RealtimeRepository realtimeRepository(Ref ref) => FirestoreRealtimeRepository(FirebaseFirestore.instance);

/// Subscribes to the relay for the watched repos and, on fresh events, fires a
/// targeted refetch of the affected providers. Kept alive at the app root
/// (watched in `TurboBoardApp`); rebuilds when the watched set changes.
///
/// - Backlog (`fromInitialSnapshot`) changes are ignored, and every docId is
///   handled at most once per session — so reconnects never replay events.
/// - Events are debounced and coalesced by repo, collapsing CI bursts into one
///   refetch per repo.
@Riverpod(keepAlive: true)
class RealtimeListener extends _$RealtimeListener {
  StreamSubscription<List<RepoEventChange>>? _sub;
  Timer? _debounceTimer;
  final Set<String> _seenDocIds = {};
  final Map<String, RepoEvent> _pending = {}; // repo -> latest pending event

  @override
  RealtimeStatus build() {
    final repos = ref.watch(watchedReposProvider);
    ref.onDispose(_teardown);
    if (repos.isEmpty) return RealtimeStatus.disabled;

    _sub = ref
        .watch(realtimeRepositoryProvider)
        .watch(repos)
        .listen(_onChanges, onError: (_) => state = RealtimeStatus.error);
    return RealtimeStatus.connecting;
  }

  void _onChanges(List<RepoEventChange> changes) {
    if (state == RealtimeStatus.connecting) state = RealtimeStatus.connected;
    for (final c in changes) {
      if (c.fromInitialSnapshot) continue; // suppress backlog
      if (!_seenDocIds.add(c.docId)) continue; // already handled this session
      _pending[c.event.repo] = c.event; // coalesce by repo (latest wins)
    }
    if (_pending.isNotEmpty) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounce, _flush);
    }
  }

  void _flush() {
    final events = _pending.values.toList();
    _pending.clear();
    for (final e in events) {
      _invalidateFor(e);
    }
  }

  void _invalidateFor(RepoEvent e) {
    final touchesBoard = switch (e.event) {
      'pull_request' || 'pull_request_review' || 'check_suite' => true,
      _ => false,
    };
    if (touchesBoard) {
      ref.invalidate(prInboxProvider);
      if (e.event == 'pull_request') {
        ref.invalidate(leadCockpitProvider);
        ref.invalidate(sprintReportProvider);
        ref.invalidate(projectsBoardProvider);
      }
    }
    // Detail: any PR-scoped event refetches the exact PR if one is open.
    final number = e.prNumber;
    if (number != null) {
      final slash = e.repo.indexOf('/');
      if (slash > 0) {
        final owner = e.repo.substring(0, slash);
        final name = e.repo.substring(slash + 1);
        ref.invalidate(prDetailProvider(owner: owner, name: name, number: number));
      }
    }
  }

  void _teardown() {
    _debounceTimer?.cancel();
    _sub?.cancel();
  }
}
