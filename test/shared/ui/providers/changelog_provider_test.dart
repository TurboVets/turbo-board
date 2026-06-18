// Test summary for parseChangelog:
// - parses version + date from "## [x] - date" headings
// - groups bullets under their "### Section" heading
// - joins wrapped (multi-line) bullets into one string
// - skips the [Unreleased] heading
// - skips entries with no bulleted content
// - orders entries as they appear (newest first)
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/shared/ui/providers/changelog_provider.dart';

const _sample = '''
# Changelog

Some intro paragraph that should be ignored.

## [Unreleased]

## [0.1.2] - 2026-06-18

### Added
- First feature.
- A wrapped bullet that continues
  on the next line.

### Changed
- A change.

## [0.1.1] - 2026-06-17

### Added
- Older feature.
''';

void main() {
  group('parseChangelog', () {
    test('parses entries newest-first, skipping Unreleased', () {
      final entries = parseChangelog(_sample);

      expect(entries.map((e) => e.version), ['0.1.2', '0.1.1']);
      expect(entries.first.date, '2026-06-18');
    });

    test('groups bullets under sections and joins wrapped bullets', () {
      final entry = parseChangelog(_sample).first;

      expect(entry.sections.map((s) => s.title), ['Added', 'Changed']);
      expect(entry.sections.first.bullets, ['First feature.', 'A wrapped bullet that continues on the next line.']);
      expect(entry.sections[1].bullets, ['A change.']);
    });

    test('allBullets flattens across sections', () {
      final entry = parseChangelog(_sample).first;
      expect(entry.allBullets.length, 3);
    });

    test('drops entries with no bulleted content', () {
      final entries = parseChangelog('## [9.9.9] - 2026-01-01\n\n### Added\n');
      expect(entries, isEmpty);
    });
  });
}
