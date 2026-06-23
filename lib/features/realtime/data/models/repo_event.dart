import 'package:freezed_annotation/freezed_annotation.dart';

part 'repo_event.freezed.dart';

/// A relay event: GitHub activity occurred on [repo]. Carries no PR contents.
@freezed
sealed class RepoEvent with _$RepoEvent {
  const factory RepoEvent({required String repo, required String event, String? action, int? prNumber}) = _RepoEvent;
}

/// One Firestore docChange surfaced to the provider layer. [fromInitialSnapshot]
/// is true for documents already present on the first snapshot (the backlog we
/// suppress) and false for changes that arrive afterward.
class RepoEventChange {
  const RepoEventChange({required this.event, required this.docId, required this.fromInitialSnapshot});

  final RepoEvent event;
  final String docId;
  final bool fromInitialSnapshot;
}

/// Maps a Firestore `repo_events` document data map to a [RepoEvent].
/// Returns null when the mandatory `repo` field is absent.
RepoEvent? repoEventFromData(Map<String, dynamic> data) {
  final repo = data['repo'];
  if (repo is! String) return null;
  return RepoEvent(
    repo: repo,
    event: (data['event'] as String?) ?? '',
    action: data['action'] as String?,
    prNumber: data['prNumber'] as int?,
  );
}
