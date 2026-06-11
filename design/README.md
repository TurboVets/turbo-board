# Mobile TurboBoard — Design

A single dashboard to watch all open PRs (and later, issues) across selected GitHub repos.
Target: Flutter desktop / Flutter web (wasm), with a thin backend for auth, CORS proxy, and real-time webhook fan-out.

## Screens in this mockup

1. **Auth / Repo Setup** — GitHub App / OAuth sign-in, then pick which repos to watch.
2. **PR Inbox board** — all open PRs across watched repos, grouped into columns by review state, with CI + review + draft badges.
2b. **Needs Attention** — inbox-style triage screen grouping PRs into actionable categories: Needs my review, Changes requested (waiting on author), Failing checks, Draft, and Stale (no updates for X days, threshold adjustable 3/5/7/14d). A PR can appear in multiple categories; nav badge shows the deduplicated count.
3. **PR Detail + comments** — checks status, review state, requested reviewers, last commit, conversation + inline review threads, comment box.
4. **Filters panel** — repo multi-select, PR status, review state, CI state, sort.

## Design direction — Tether Design System v2.0

Rebuilt against the **Tether Design System for TurboVets** (Figma file `q3X6qtSNiJbSxzrgZiaRQD`).
Tagline: *Beside you. Behind you. After you.*

- **Theme:** Dark zinc canvas (`#18181b`, verified `Color/Background/primary`) with a faint grid, thin **blue top rail** + **Shiraz-red bottom rail** with square end-caps, crosshair "T" brand mark.
- **Feel:** Technical but soft-edged — verified radii are **4px small / 8px medium** (not the 3px originally assumed).
- **Type:** *Inclusive Sans* (Medium, −1% tracking) for body; **Akshar** (verified display face) for uppercase labels and metadata.
- **Layout:** Desktop-first three-region shell — left rail (nav/repos), center board, right detail/filter column.
- **Status colors:** functional extensions of the brand for CI/review (passing = green, pending = amber, failing/changes = Shiraz red, needs review = Tether blue, waiting = grey).

## Brand tokens (from Figma)

| Token | Hex | Use |
|---|---|---|
| `--tv-main-bg` | `#0b0b0c` | App background |
| `--tv-blue-500` | `#0073ff` | Primary accent / actions |
| `--tv-blue-600` | `#008bff` | Bright blue / hover |
| `--tv-blue-950` | `#0a3161` | Deep navy |
| `--tv-red-700` | `#b11c3b` | Shiraz red (danger, bottom rail) |
| `--tv-red-950` | `#480919` | Deep Shiraz |
| `--text` | `#f4f4f6` | Primary text |
| `--muted` | `#9a9aa2` | Secondary text |
| `--dim` | `#5c5c5c` | Tertiary / labels |

### Verified semantic tokens (from component library, node `183-20591`)

| Token | Value | Source |
|---|---|---|
| `Color/Background/primary` (dark) | `#18181b` | verified |
| `Radius/small` / `Radius/medium` | `4px` / `8px` | verified |
| `Font/Size/small` / `default` / `xx-huge` | `12` / `14` / `46` | verified |
| Display face | Akshar | verified (`Display/H1`) |
| Signal face | Inclusive Sans Medium, −1% tracking | verified |
| `--surface` / `--surface-2` | `#1e1e21` / `#27272a` | surface-2 = verified `gray-bg`; surface interpolated |

### Signal palette · dark mode (verified) — recipe: deep bg + bright border + pale text

| Signal | bg | border | text | Mapped to |
|---|---|---|---|---|
| Green | `#10280b` | `#54ae39` | `#ceefc3` | CI passing / approved |
| Yellow | `#3d2a00` | `#ffb000` | `#ffe58a` | CI pending |
| Red | `#480919` | `#e94a5f` | `#fbd0d3` | CI failing / changes requested |
| Blue | `#0a3161` | `#13acff` | `#b2ebff` | Needs review / draft info |
| Gray | `#27272a` | `#babbbf` | `#dadadd` | Waiting / draft |
| Orange | `#421406` | `#ff5a1f` | `#ffc2a3` | Stale |

> Purple (`#200c42`/`#9b5cff`/`#d0b3ff`) and Teal (`#002f2c`/`#00cbb7`/`#8efff0`) are also in the verified palette, currently unmapped.
> Remaining unverified: exact border/divider tokens and per-component tokens (buttons, inputs, tables) — share links to those library sections to true those up too.

## Files

- `mockup.html` — self-contained interactive mockup (open in any browser).

## Next steps

- Swap in exact TurboVets brand colors + logo.
- Wire the board to the GitHub GraphQL `search` query.
- Add SSE/WebSocket live updates from the backend webhook receiver.
