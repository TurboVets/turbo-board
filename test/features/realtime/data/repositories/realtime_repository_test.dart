// Test summary:
// - repoEventFromData maps a full document
// - repoEventFromData returns null when `repo` is missing
// - (Task 6) chunkRepos splits a list into <=30-sized batches
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/realtime/data/models/repo_event.dart';

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
  });
}
