import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart' show Rx;

import '../models/repo_event.dart';

/// Streams relay doc-changes for the watched repos.
abstract class RealtimeRepository {
  Stream<List<RepoEventChange>> watch(List<String> repos);
}

/// Splits [repos] into chunks of at most [size]. Firestore `whereIn` caps at 30
/// values, so larger watched-repo lists are queried in parallel batches.
List<List<String>> chunkRepos(List<String> repos, {int size = 30}) {
  final chunks = <List<String>>[];
  for (var i = 0; i < repos.length; i += size) {
    chunks.add(repos.sublist(i, i + size > repos.length ? repos.length : i + size));
  }
  return chunks;
}

/// Live Firestore implementation. Each per-chunk snapshot tags its doc changes
/// with `fromInitialSnapshot` so the provider can suppress the backlog; the
/// provider also dedups by docId, so re-emitting is harmless.
class FirestoreRealtimeRepository implements RealtimeRepository {
  FirestoreRealtimeRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<RepoEventChange>> watch(List<String> repos) {
    if (repos.isEmpty) return const Stream.empty();
    final streams = chunkRepos(repos).map((chunk) {
      var firstSnapshot = true;
      return _db.collection('repo_events').where('repo', whereIn: chunk).orderBy('ts').snapshots().map((snap) {
        final initial = firstSnapshot;
        firstSnapshot = false;
        return snap.docChanges
            .where((c) => c.type == DocumentChangeType.added)
            .map((c) {
              final event = repoEventFromData(c.doc.data() ?? const {});
              return event == null
                  ? null
                  : RepoEventChange(event: event, docId: c.doc.id, fromInitialSnapshot: initial);
            })
            .whereType<RepoEventChange>()
            .toList();
      });
    }).toList();
    return Rx.merge(streams);
  }
}

/// In-memory implementation for tests and offline. Tests drive [emit].
class MockRealtimeRepository implements RealtimeRepository {
  final _controller = StreamController<List<RepoEventChange>>.broadcast();

  void emit(List<RepoEventChange> changes) => _controller.add(changes);

  @override
  Stream<List<RepoEventChange>> watch(List<String> repos) => _controller.stream;

  void dispose() => _controller.close();
}
