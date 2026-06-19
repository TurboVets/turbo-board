# Changelog

All notable changes to TurboBoard are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release process: bump `version:` in `pubspec.yaml` and add an entry here every
release. The app reads its version from the bundle (generated from `pubspec.yaml`)
and shows it at the bottom of the nav rail.

## [Unreleased]

## [0.2.1] - 2026-06-19

### Added
- **Choose your AI provider** — AI features now work with **OpenAI** as well as
  Anthropic. Pick a provider in Settings and paste that provider's key
  (bring-your-own-key, stored only on your device). (#4)

### Changed
- AI features are now provider-agnostic under the hood; if you already had an
  Anthropic key saved, it carries over automatically — no need to re-enter it.
  (#4)
- AI results (PR/issue summaries, reply drafts, inbox triage, sprint and weekly
  digests) now stick around for the session, so leaving a screen and coming back
  no longer throws away what was generated — or spends another API call to
  regenerate it. (#4)

## [0.2.0] - 2026-06-18

### Added
- **Projects Board** — a GitHub ProjectV2 kanban grouped by Status, with mixed
  issue/PR cards, sprint tabs (current / previous / next / all), an on-demand AI
  per-column insights CTA, and a phone column selector.
- **Issue Detail** drawer — a ProjectV2-enriched issue view: markdown body,
  sub-issue task list, linked PRs, full activity timeline + comment composer
  (comment, close/reopen, create branch, open in GitHub Desktop), an AI TL;DR +
  "suggest next action", and a project-field sidebar. Opens from board issue
  cards, Lead Cockpit stuck rows, and a PR Detail ↔ Issue cross-link.
- Issue Detail: change **Status** from the sidebar via a dropdown; the board
  view refreshes so the card moves columns.
- Issue Detail: a confirm dialog with an editable branch name before creating a
  branch.
- Projects Board: **filter tickets by assignee**, including an Unassigned option.
- Board view **toggle** — fit all columns into the width, or scroll through them
  horizontally; remembered per board (PR Board and Projects Board).
- Board cards are bordered with the assignee's avatar color for quick scanning.

### Changed
- Detail drawers (Issue and PR) now fill the content area right up to the nav
  rail, and tapping anywhere on the nav bar dismisses an open drawer.
- Avatars now give each user a distinct color.
- Board columns share a single fit/scroll mechanism across the PR and Projects
  boards.

### Fixed
- Filled buttons (Comment, Create, …) are now readable in the dark theme
  (blue fill, white label).

## [0.1.2] - 2026-06-18

### Added
- PR Detail: a "Files changed" button in the header that opens the PR's Files
  changed (diff) tab on github.com.
- PR Detail: an "Open in Desktop" button that checks out the PR's branch in the
  GitHub Desktop app via its deep-link scheme.
- PR cards: a "Conflicts" badge that surfaces mergeability against the base
  branch (`mergeState` is now fetched and modelled).
- "What's new" dialog, opened from a button at the end of the version row in the
  nav rail; shows the latest release notes read from this `CHANGELOG.md`.

### Changed
- PR Detail markdown: GitHub task-list items (`- [x]` / `- [ ]`) now render as
  right-sized icons, and headings are scaled to match the app's body text.
- Settings: filtering is now applied live as you type.

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
