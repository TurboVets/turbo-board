// Test summary:
// - repoEventFromData maps a full document
// - repoEventFromData returns null when `repo` is missing
// - repoEventFromData returns null when `event` is missing
// - (Task 6) chunkRepos splits a list into <=30-sized batches
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/realtime/data/models/repo_event.dart';
import 'package:turbo_board/features/realtime/data/repositories/realtime_repository.dart';

void main() {
  group('repoEventFromData', () {
    test('maps a full document', () {
      final e = repoEventFromData({'repo': 'acme/web', 'event': 'pull_request', 'action': 'opened', 'prNumber': 42});
      expect(e, isNotNull);
      expect(e!.repo, 'acme/web');
      expect(e.event, 'pull_request');
      expect(e.action, 'opened');
      expect(e.prNumber, 42);
    });

    test('returns null when repo is missing', () {
      expect(repoEventFromData({'event': 'pull_request'}), isNull);
    });

    test('returns null when event is missing', () {
      expect(repoEventFromData({'repo': 'acme/web'}), isNull);
    });
  });

  group('chunkRepos', () {
    test('returns a single chunk when under the cap', () {
      expect(chunkRepos(['a', 'b', 'c']), [
        ['a', 'b', 'c'],
      ]);
    });

    test('splits into <=30-sized chunks', () {
      final repos = List.generate(65, (i) => 'r$i');
      final chunks = chunkRepos(repos);
      expect(chunks.length, 3);
      expect(chunks[0].length, 30);
      expect(chunks[1].length, 30);
      expect(chunks[2].length, 5);
    });

    test('empty in -> empty out', () {
      expect(chunkRepos(const []), isEmpty);
    });
  });
}
