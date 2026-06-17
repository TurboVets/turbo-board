# Changelog

All notable changes to TurboBoard are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release process: bump `version:` in `pubspec.yaml` and add an entry here every
release. The app reads its version from the bundle (generated from `pubspec.yaml`)
and shows it at the bottom of the nav rail.

## [Unreleased]

## [0.1.1] - 2026-06-17

### Added
- App version label at the bottom of the nav rail (above the user row), read
  from `pubspec.yaml` via `package_info_plus`.
- This `CHANGELOG.md` and a documented per-release versioning process.

### Changed
- Lead Cockpit: hid the `OVERLOADED` badge and red card border on team load
  cards until the thresholds are calibrated for the team's velocity. Overload
  was also dropped from the AI sprint brief and weekly digest prompts.

## [0.1.0] - 2026-06-16

### Added
- Initial TurboBoard: PR Board, Needs Attention, PR Detail (merge / delete
  branch), Lead Cockpit, Sprint Report, repo setup, and BYOK Anthropic AI
  features (summaries, triage, reply drafts, sprint narratives).
