# Sprint Report — Narrative Report & Export

**Date:** 2026-06-23
**Branch:** `feat/sprint-report-export`
**Status:** Approved design

## Summary

Add a **narrative executive Sprint Report** that an engineering lead can generate
on demand and export as **PDF** or **email/copied summary**. The existing
`sprint_report` feature renders an analytical data rollup (points, status,
per-assignee, epics, burndown). This adds a second, prose-oriented artifact built
for sharing with stakeholders: Executive Summary, Key Wins, Overall Status, Major
Deliverables, Technical Highlights, Metrics, Challenges & Risks, Learnings, Next
Sprint Priorities, Team Recognition, Sprint Outcome.

The narrative prose is **AI-generated (BYOK), on demand from a CTA** — never auto.
The report is **generated-then-exported as-is** for v1 (no inline prose editor).

## Goals

- One-tap "Generate Sprint Report" CTA → structured narrative grounded in real
  board/PR data.
- Export the generated report as a clean **light** (print/forward-friendly) PDF.
- Export/copy a plain-text summary suitable for pasting into an email (+ `mailto:`).
- Full vs Digest length toggle.
- Cross-platform: macOS, Windows, Linux, web, iOS/Android tablets.

## Non-Goals (v1)

- Inline rich-text editing of generated prose (regenerate instead).
- Persisting generated reports or custom metrics across sessions.
- Programmatic email *sending* / attachment plumbing (we copy + open `mailto:`,
  the user attaches the PDF themselves).
- Fetching/diffing arbitrary infra metrics — see Honesty Constraint.

## Honesty Constraint (load-bearing)

A GitHub PR/issue board **cannot** produce infra metrics like API latency,
uptime, or test-coverage %. The AI **must never fabricate** these.

Every report value is one of three provenances:

- **REAL** — computed deterministically from `SprintReport` (and previous sprint
  for deltas): sprint period, overall status (from forecast), deliverables (epics
  / completed work), points delivered, tickets closed, top contributors.
- **AI** — BYOK-generated prose grounded *only* in the supplied board data:
  Executive Summary, Key Wins, Business Impact, Technical Highlights, Challenges &
  Risks, Learnings, Next Priorities, Team Recognition, Outcome.
- **YOU** — optional custom metric rows the user types into the export dialog
  (e.g. latency, uptime). In-memory for the session only. AI never touches these.

The AI prompt explicitly forbids inventing numbers not present in its input.

## Architecture

New code lives inside the existing `sprint_report` feature, plus one method on the
shared `AiRepository`.

```
lib/features/sprint_report/
  data/
    models/
      sprint_narrative_report.dart   # Freezed: the structured narrative (AI output shape)
    export/
      report_metrics.dart            # pure: SprintReport (+prev) -> REAL metric rows
      sprint_export_format.dart       # enum { fullReport, digest }
      sprint_pdf_builder.dart         # pure: (narrative, metrics, custom) -> pw.Document (light)
      sprint_email_builder.dart       # pure: (...) -> ({String subject, String body})
      sprint_exporter.dart            # interface + default impl (Clipboard / url_launcher / Printing)
  presentation/
    providers/
      sprint_narrative_controller.dart # AsyncValue<SprintNarrativeReport>? generate()/clear()
      sprint_export_provider.dart      # @Riverpod(keepAlive) SprintExporter (override in tests)
    view/widgets/
      generate_report_button.dart      # header CTA pill
      report_export_dialog.dart        # preview + format toggle + custom rows + Copy/Email/PDF

lib/features/ai/
  data/repositories/ai_repository.dart # + Future<Result<SprintNarrativeReport>> generateSprintReport(SprintReport)
  presentation/helpers/ai_prompts.dart # + buildSprintReportPrompt(SprintReport) -> structured-JSON prompt
```

### Dependencies (new)

- `pdf` (^3.x) — document model. All 6 platforms.
- `printing` (^5.x) — `Printing.layoutPdf(...)`: native save/print on desktop,
  share sheet on mobile, browser print on web. All 6 platforms.

`url_launcher` (mailto) and `flutter/services` `Clipboard` are already in use.
Verify both new packages on pub.dev for the six targets before adding (Platform
Rule 1).

## Components

### 1. `SprintNarrativeReport` model (Freezed)

The structured shape the AI returns and the builders consume:

```dart
@freezed sealed class SprintNarrativeReport {
  String executiveSummary;
  List<String> keyWins;
  SprintHealth overallStatus;            // enum onTrack | atRisk | behind  (REAL, set post-AI)
  List<Deliverable> deliverables;        // title, status, description, impact
  TechHighlights techHighlights;         // platform[], product[]
  List<String> challenges;
  List<String> mitigations;
  List<String> learnings;
  List<String> nextPriorities;
  List<String> recognition;
  String outcome;
}
```

`overallStatus` is **not** trusted from the AI — it is overwritten from the
deterministic forecast (`SprintReport.behind` + forecast label) after the call.
`fromJson` tolerates missing/short lists (default `[]`).

### 2. `report_metrics.dart` (pure)

Computes the **REAL** metric rows from the current `SprintReport` and, when
available, the previous sprint (via `sprintTitles`/`sprintIndex`): points
delivered, tickets closed, % done, unestimated coverage, contributor count, with
prev→current deltas where a previous sprint can be loaded. Returns
`List<MetricRow>` (label, prev?, current, deltaLabel?). No AI, no I/O.

> v1 scope: deltas use whatever previous-sprint data is already fetchable through
> the existing `sprintReportProvider` family. If a previous sprint isn't loaded,
> rows render current-only (no delta) rather than blocking. This is the one place
> we may defer prev-sprint fetching to a follow-up; called out so it isn't a
> silent gap.

### 3. AI generation (`generateSprintReport`)

`buildSprintReportPrompt(SprintReport)` compiles the board data (sprint name,
period, points by status, epics + %, per-assignee done/open, forecast, unestimated)
into a prompt asking for **JSON** matching `SprintNarrativeReport`, with explicit
instructions: ground every statement in the provided data; do not invent metrics,
dates, or names not present. `LlmAiRepository.generateSprintReport` reuses the
existing structured-output path (mirror `triage`/`boardInsights`: request JSON,
parse, validate, `Result.success/failure`). Errors stay in the repo layer and
surface as `Result.failure`.

### 4. `SprintNarrativeController` (Riverpod)

Mirrors `SprintSummaryController`: `AsyncValue<SprintNarrativeReport>?` (null =
not requested). `generate(SprintReport)` sets loading, calls the repo, sets
data/error, and stamps `overallStatus` from the report's forecast. `clear()`
resets to null. Gated behind the BYOK key-ready check (`aiKeyReadyProvider`),
same as the existing sprint AI cards.

### 5. `SprintExporter` (interface + default impl)

```dart
abstract interface class SprintExporter {
  Future<void> copySummary(String text);          // Clipboard
  Future<bool> openEmail(String subject, String body); // mailto via url_launcher; false if no client
  Future<void> printOrSavePdf(Uint8List bytes, String filename); // Printing.layoutPdf
}
```

Default impl wraps `Clipboard` / `url_launcher` / `Printing`. Provided via
`@Riverpod(keepAlive)` so tests/mock-mode substitute a fake. Keeps platform calls
out of widgets and pure builders.

### 6. Builders (pure)

- `sprint_pdf_builder.dart` → `pw.Document` on a **light** theme (white page, dark
  text, Tether accent colors for status chips/bars). Full = all sections; Digest =
  Executive Summary + Status + top deliverables + REAL metrics, one page. Burndown
  not included in the narrative PDF (it lives on the analytical screen); the
  narrative leads with prose + metrics.
- `sprint_email_builder.dart` → `(subject, body)` plain text / light markdown
  (the format shown in mockup C). Same content, length scaled by format.

### 7. UI

- `generate_report_button.dart` — an **EXPORT / GENERATE REPORT** pill in the
  Sprint Report header (next to REFRESH). Disabled with a tooltip when no BYOK key.
- `report_export_dialog.dart` (`HookConsumerWidget`) — opened by the CTA:
  - If narrative not yet generated → shows a generate step (fires
    `sprintNarrativeControllerProvider.generate(report)`), loading shimmer reusing
    the existing AI card treatment.
  - Once generated → scrollable **preview** of the rendered report, a
    Full/Digest segmented toggle (`TetherSegmentedButtonGroup`), an optional
    "add custom metric" mini-form (label / prev / current, in-memory list), and a
    row of actions: **Copy summary** · **Email** · **PDF**.
  - Actions call the builders then the `SprintExporter`. Each wrapped in
    try/catch → `SnackBar` on failure. `openEmail` returning false → snackbar
    "No mail client — summary copied to clipboard" (we copy alongside mailto as a
    fallback).

## Data Flow

```
Header CTA ─▶ report_export_dialog(report)
                 │  (BYOK key ready?)
                 ▼
        sprintNarrativeController.generate(report)
                 │  AiRepository.generateSprintReport → JSON → SprintNarrativeReport
                 ▼  (overallStatus stamped from forecast)
        preview  ─▶ format toggle + custom rows
                 │
   ┌─────────────┼──────────────┐
   ▼             ▼              ▼
Copy          Email           PDF
builder→text  builder→text    pdf_builder→bytes
Clipboard     mailto+copy     Printing.layoutPdf
```

## Error Handling

- AI failures: `Result.failure` → controller `AsyncError` → dialog shows red
  message + Retry (reuse AI card error treatment).
- Export failures (`url_launcher`/`Printing` throw): caught in the dialog →
  `SnackBar`. Copy-to-clipboard runs as the email fallback.
- Missing previous sprint: metrics render current-only, no crash.

## Testing

- **`report_metrics`** (unit, pure): given a `SprintReport` (+ optional prev),
  asserts correct rows, deltas, and current-only fallback.
- **`sprint_email_builder`** (unit, pure): body contains sprint name, % done,
  status numbers; digest is shorter than full; custom rows appear.
- **`sprint_pdf_builder`** (unit): builds a `pw.Document` without throwing for
  full + digest, with and without AI narrative / custom rows.
- **`generateSprintReport`** (repo, mocked `LlmClient`): valid JSON → populated
  model; malformed JSON → `Result.failure`; AI-supplied status ignored.
- **`report_export_dialog`** (widget): inject a fake `SprintExporter`; assert
  Copy/Email/PDF invoke the right exporter method with builder output, format
  toggle changes content, error path shows snackbar.

## Pre-Completion

`dart run build_runner build -d`, `dart format --line-length 120 --set-exit-if-changed .`,
`dart analyze`, `flutter test`. Verify on macOS + web (Platform Rule + Pre-PR).
