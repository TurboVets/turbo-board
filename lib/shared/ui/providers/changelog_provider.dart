import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'changelog_provider.g.dart';

/// One `### Heading` block within a release (e.g. "Added") and its bullets.
class ChangeSection {
  const ChangeSection({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;
}

/// One `## [version] - date` release entry parsed from `CHANGELOG.md`.
class ChangelogEntry {
  const ChangelogEntry({required this.version, required this.date, required this.sections});

  final String version;
  final String? date;
  final List<ChangeSection> sections;

  /// Flat list of every bullet across all sections — used as a fallback when a
  /// caller just wants the highlights without the section grouping.
  List<String> get allBullets => [for (final s in sections) ...s.bullets];
}

/// Parses Keep-a-Changelog markdown into release entries, newest first.
/// Skips the `[Unreleased]` heading and any entry with no bulleted content.
/// Multi-line bullets (a wrapped continuation line) are joined into one string.
List<ChangelogEntry> parseChangelog(String raw) {
  final entries = <ChangelogEntry>[];

  String? version;
  String? date;
  var sections = <ChangeSection>[];
  String? sectionTitle;
  var bullets = <String>[];
  StringBuffer? bullet;

  void flushBullet() {
    if (bullet != null) {
      final text = bullet.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isNotEmpty) bullets.add(text);
      bullet = null;
    }
  }

  void flushSection() {
    flushBullet();
    if (sectionTitle != null && bullets.isNotEmpty) {
      sections.add(ChangeSection(title: sectionTitle!, bullets: List.of(bullets)));
    }
    sectionTitle = null;
    bullets = <String>[];
  }

  void flushEntry() {
    flushSection();
    if (version != null && version != 'Unreleased' && sections.isNotEmpty) {
      entries.add(ChangelogEntry(version: version!, date: date, sections: List.of(sections)));
    }
    version = null;
    date = null;
    sections = <ChangeSection>[];
  }

  final bulletStart = RegExp(r'^\s*-\s+');
  for (final line in raw.split('\n')) {
    if (line.startsWith('## ')) {
      flushEntry();
      // "## [0.1.2] - 2026-06-18" or "## [Unreleased]"
      final m = RegExp(r'^##\s+\[([^\]]+)\](?:\s*-\s*(.+))?').firstMatch(line);
      if (m != null) {
        version = m.group(1)!.trim();
        date = m.group(2)?.trim();
      }
    } else if (line.startsWith('### ')) {
      flushSection();
      sectionTitle = line.substring(4).trim();
    } else if (bulletStart.hasMatch(line)) {
      flushBullet();
      bullet = StringBuffer(line.replaceFirst(bulletStart, ''));
    } else if (line.trim().isEmpty) {
      flushBullet();
    } else if (bullet != null) {
      // Wrapped continuation of the current bullet.
      bullet!.write(' ');
      bullet!.write(line.trim());
    }
  }
  flushEntry();

  return entries;
}

/// All release entries from the bundled `CHANGELOG.md`, newest first.
@Riverpod(keepAlive: true)
Future<List<ChangelogEntry>> changelog(Ref ref) async {
  final raw = await rootBundle.loadString('CHANGELOG.md');
  return parseChangelog(raw);
}
