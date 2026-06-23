# Webhook Backend + Realtime Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reflect GitHub PR activity on the board within seconds via a webhook→Firestore signal relay, while preserving the BYOK trust model (backend stores no PR data and no tokens).

**Architecture:** A Firebase Cloud Function (`githubWebhook`) verifies the GitHub HMAC signature and writes a tiny `{repo, event, action, prNumber, ts, expireAt}` doc to Firestore `repo_events`. Flutter clients sign in anonymously, listen to `repo_events` for their watched repos, suppress the initial backlog, debounce bursts, and invalidate the matching Riverpod providers — which then refetch with each client's own PAT. Polling stays as a stretched fallback.

**Tech Stack:** Firebase Cloud Functions Gen 2 (TypeScript, tested with Vitest), Firestore, Flutter (Riverpod codegen, Freezed, `cloud_firestore`, `firebase_auth`).

## Global Constraints

- **Cross-platform:** every Dart dependency must support macOS, Windows, Linux, web, Android, iOS. `cloud_firestore` and `firebase_auth` do. (CLAUDE.md Platform Rules.)
- **Depend on `turbo_core` + `turbo_ui` directly, never `turbo_sdk`.**
- **Secrets** (`WEBHOOK_SECRET`) live in Firebase Secret Manager — never hardcoded, logged, or committed. GitHub tokens / API keys stay in `flutter_secure_storage`.
- **Models:** `@freezed sealed class` + `fromJson`, part directives, `@Default()` for defaults.
- **State:** Riverpod codegen (`@Riverpod(keepAlive: true)` for persistent, `@riverpod` for autodispose). Run `dart run build_runner build -d` after model/provider changes.
- **Errors above repo layer:** `Result<T>` from turbo_core; `try/catch` only inside the repo layer.
- **Format:** `dart format --line-length 120 --set-exit-if-changed .` must pass. Then `dart analyze`, then `flutter test`.
- **Commits:** Conventional Commits. End commit messages with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Branch:** `feat/webhook-realtime` (already created).

## File Structure

**Backend (new `functions/`):**
- `functions/package.json`, `functions/tsconfig.json`, `functions/.gitignore`
- `functions/src/verify.ts` — pure HMAC signature verification.
- `functions/src/map_event.ts` — pure payload → event-record mapping.
- `functions/src/index.ts` — `githubWebhook` HTTPS handler (composes verify + map + Firestore write).
- `functions/test/verify.test.ts`, `functions/test/map_event.test.ts`
- `firestore.rules`, `firestore.indexes.json` — rules + composite index for the events query.
- `firebase.json` — add `functions` + `firestore` blocks.

**Client (new `lib/features/realtime/`):**
- `data/models/repo_event.dart` — `RepoEvent` (Freezed) + `RepoEventChange` (event + docId + fromInitialSnapshot).
- `data/repositories/realtime_repository.dart` — interface, `FirestoreRealtimeRepository`, `MockRealtimeRepository`, `chunkRepos` helper, `repoEventFromData` mapper.
- `presentation/providers/realtime_provider.dart` — `realtimeRepositoryProvider`, `RealtimeListener` notifier (subscription + suppression + debounce + invalidation), exposes `RealtimeStatus`.

**Client (modified):**
- `pubspec.yaml` — add `cloud_firestore`, `firebase_auth`.
- `lib/main.dart` — anonymous sign-in after `Firebase.initializeApp`.
- `lib/app.dart:57` — watch `realtimeListenerProvider` beside `autoRefreshProvider`.
- `lib/shared/ui/providers/auto_refresh_provider.dart` — stretch interval while realtime connected.
- Repo-setup screen — webhook setup instructions card.

**Tests (new):**
- `test/features/realtime/data/repositories/realtime_repository_test.dart`
- `test/features/realtime/presentation/providers/realtime_provider_test.dart`
- `test/shared/ui/providers/auto_refresh_provider_test.dart` — extend existing.

---

## Task 1: Backend scaffold + HMAC signature verification

**Files:**
- Create: `functions/package.json`, `functions/tsconfig.json`, `functions/.gitignore`
- Create: `functions/src/verify.ts`
- Test: `functions/test/verify.test.ts`

**Interfaces:**
- Produces: `verifySignature(rawBody: Buffer | string, signatureHeader: string | undefined, secret: string): boolean` — constant-time compare of `sha256=<hex>` against HMAC-SHA256(rawBody, secret). Returns `false` for missing/malformed headers.

- [ ] **Step 1: Scaffold the functions package**

`functions/package.json`:
```json
{
  "name": "turboboard-functions",
  "engines": { "node": "20" },
  "main": "lib/index.js",
  "type": "commonjs",
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "deploy": "npm run build && firebase deploy --only functions"
  },
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^6.0.0"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "vitest": "^2.0.0"
  }
}
```

`functions/tsconfig.json`:
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2021",
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

`functions/.gitignore`:
```
node_modules/
lib/
```

- [ ] **Step 2: Write the failing test**

`functions/test/verify.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import { createHmac } from "node:crypto";
import { verifySignature } from "../src/verify";

const secret = "topsecret";
function sign(body: string): string {
  return "sha256=" + createHmac("sha256", secret).update(body).digest("hex");
}

describe("verifySignature", () => {
  const body = JSON.stringify({ action: "opened" });

  it("accepts a correct signature", () => {
    expect(verifySignature(body, sign(body), secret)).toBe(true);
  });

  it("rejects a wrong signature", () => {
    expect(verifySignature(body, sign("tampered"), secret)).toBe(false);
  });

  it("rejects a missing header", () => {
    expect(verifySignature(body, undefined, secret)).toBe(false);
  });

  it("rejects a malformed header", () => {
    expect(verifySignature(body, "garbage", secret)).toBe(false);
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd functions && npm install && npx vitest run test/verify.test.ts`
Expected: FAIL — `verifySignature` not found / module missing.

- [ ] **Step 4: Implement `verify.ts`**

`functions/src/verify.ts`:
```ts
import { createHmac, timingSafeEqual } from "node:crypto";

/** Verify GitHub's X-Hub-Signature-256 header against the shared secret. */
export function verifySignature(
  rawBody: Buffer | string,
  signatureHeader: string | undefined,
  secret: string,
): boolean {
  if (!signatureHeader || !signatureHeader.startsWith("sha256=")) return false;
  const expected = "sha256=" + createHmac("sha256", secret).update(rawBody).digest("hex");
  const a = Buffer.from(signatureHeader);
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd functions && npx vitest run test/verify.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add functions/package.json functions/tsconfig.json functions/.gitignore functions/src/verify.ts functions/test/verify.test.ts
git commit -m "feat(functions): scaffold + HMAC webhook signature verification

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Backend payload → event mapping

**Files:**
- Create: `functions/src/map_event.ts`
- Test: `functions/test/map_event.test.ts`

**Interfaces:**
- Consumes: nothing from prior tasks.
- Produces:
  ```ts
  export interface RepoEventRecord {
    repo: string;          // payload.repository.full_name
    event: string;         // X-GitHub-Event value
    action: string | null; // payload.action
    prNumber: number | null;
  }
  export function mapEvent(eventName: string, payload: any): RepoEventRecord | null;
  ```
  Returns `null` when `payload.repository.full_name` is absent (event not mappable).

- [ ] **Step 1: Write the failing test**

`functions/test/map_event.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import { mapEvent } from "../src/map_event";

describe("mapEvent", () => {
  it("maps a pull_request event with the PR number", () => {
    const r = mapEvent("pull_request", {
      action: "opened",
      repository: { full_name: "acme/web" },
      pull_request: { number: 42 },
    });
    expect(r).toEqual({ repo: "acme/web", event: "pull_request", action: "opened", prNumber: 42 });
  });

  it("maps issue_comment on a PR using issue.number", () => {
    const r = mapEvent("issue_comment", {
      action: "created",
      repository: { full_name: "acme/web" },
      issue: { number: 7 },
    });
    expect(r).toEqual({ repo: "acme/web", event: "issue_comment", action: "created", prNumber: 7 });
  });

  it("maps check_suite with no PR number", () => {
    const r = mapEvent("check_suite", {
      action: "completed",
      repository: { full_name: "acme/web" },
    });
    expect(r).toEqual({ repo: "acme/web", event: "check_suite", action: "completed", prNumber: null });
  });

  it("returns null when repository is missing", () => {
    expect(mapEvent("pull_request", { action: "opened" })).toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd functions && npx vitest run test/map_event.test.ts`
Expected: FAIL — `mapEvent` not found.

- [ ] **Step 3: Implement `map_event.ts`**

`functions/src/map_event.ts`:
```ts
export interface RepoEventRecord {
  repo: string;
  event: string;
  action: string | null;
  prNumber: number | null;
}

export function mapEvent(eventName: string, payload: any): RepoEventRecord | null {
  const repo = payload?.repository?.full_name;
  if (typeof repo !== "string") return null;
  const prNumber =
    typeof payload?.pull_request?.number === "number"
      ? payload.pull_request.number
      : typeof payload?.issue?.number === "number"
        ? payload.issue.number
        : null;
  return {
    repo,
    event: eventName,
    action: typeof payload?.action === "string" ? payload.action : null,
    prNumber,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd functions && npx vitest run test/map_event.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add functions/src/map_event.ts functions/test/map_event.test.ts
git commit -m "feat(functions): map webhook payloads to event records

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `githubWebhook` HTTPS handler

**Files:**
- Create: `functions/src/index.ts`

**Interfaces:**
- Consumes: `verifySignature` (Task 1), `mapEvent` + `RepoEventRecord` (Task 2).
- Produces: deployed function `githubWebhook`. Doc id = `X-GitHub-Delivery`. Doc fields: `{repo, event, action, prNumber, ts: serverTimestamp(), expireAt: now + 24h}`.

Note: this handler is verified by deploy + a live webhook delivery (Task 8), not a unit test — it is thin glue over the two pure functions already tested. Keep all logic in `verify.ts`/`map_event.ts`.

- [ ] **Step 1: Implement `index.ts`**

`functions/src/index.ts`:
```ts
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { verifySignature } from "./verify";
import { mapEvent } from "./map_event";

initializeApp();
const WEBHOOK_SECRET = defineSecret("WEBHOOK_SECRET");
const TTL_MS = 24 * 60 * 60 * 1000;

export const githubWebhook = onRequest({ secrets: [WEBHOOK_SECRET] }, async (req, res) => {
  // req.rawBody is the exact bytes GitHub signed — required for a correct HMAC.
  const signature = req.header("x-hub-signature-256");
  if (!verifySignature(req.rawBody, signature, WEBHOOK_SECRET.value())) {
    res.status(401).send("invalid signature");
    return;
  }

  const eventName = req.header("x-github-event") ?? "";
  const deliveryId = req.header("x-github-delivery");
  const record = mapEvent(eventName, req.body);
  if (!deliveryId || !record) {
    res.status(204).send(); // ack but nothing to relay (e.g. ping)
    return;
  }

  await getFirestore()
    .collection("repo_events")
    .doc(deliveryId) // idempotent: GitHub retries reuse the delivery id
    .set({
      repo: record.repo,
      event: record.event,
      action: record.action,
      prNumber: record.prNumber,
      ts: FieldValue.serverTimestamp(),
      expireAt: Timestamp.fromMillis(Date.now() + TTL_MS),
    });

  res.status(204).send();
});
```

- [ ] **Step 2: Verify it compiles**

Run: `cd functions && npm run build`
Expected: `tsc` exits 0, emits `functions/lib/index.js`.

- [ ] **Step 3: Commit**

```bash
git add functions/src/index.ts
git commit -m "feat(functions): githubWebhook handler writes relay events to Firestore

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Firestore rules, index, and firebase.json wiring

**Files:**
- Create: `firestore.rules`, `firestore.indexes.json`
- Modify: `firebase.json`

**Interfaces:**
- Produces: deployable Firestore config. Clients can read `repo_events` only when authenticated; no client writes. Composite index supports `where('repo', whereIn: …).orderBy('ts')`.

- [ ] **Step 1: Write `firestore.rules`**

`firestore.rules`:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /repo_events/{id} {
      allow read: if request.auth != null;
      allow write: if false; // Admin SDK (Cloud Function) bypasses rules
    }
  }
}
```

- [ ] **Step 2: Write `firestore.indexes.json`**

The client query filters `repo in [...]` and orders by `ts`, which needs a composite index.

`firestore.indexes.json`:
```json
{
  "indexes": [
    {
      "collectionGroup": "repo_events",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "repo", "order": "ASCENDING" },
        { "fieldPath": "ts", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

- [ ] **Step 3: Add `functions` + `firestore` blocks to `firebase.json`**

Add these two top-level keys to the existing object in `firebase.json` (alongside `hosting` and `flutter`):
```json
  "functions": {
    "source": "functions",
    "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  }
```

- [ ] **Step 4: Validate JSON**

Run: `node -e "JSON.parse(require('fs').readFileSync('firebase.json','utf8')); JSON.parse(require('fs').readFileSync('firestore.indexes.json','utf8')); console.log('ok')"`
Expected: prints `ok`.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules firestore.indexes.json firebase.json
git commit -m "feat(firestore): auth-gated repo_events rules + index + firebase config

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Client dependencies + `RepoEvent` model

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/realtime/data/models/repo_event.dart`
- Test: `test/features/realtime/data/repositories/realtime_repository_test.dart` (model-mapping cases; repository cases added in Task 6)

**Interfaces:**
- Produces:
  ```dart
  @freezed sealed class RepoEvent ... {
    const factory RepoEvent({
      required String repo,
      required String event,
      String? action,
      int? prNumber,
    }) = _RepoEvent;
  }
  /// One Firestore docChange surfaced to the provider. `fromInitialSnapshot`
  /// is true for docs already present on the first snapshot (backlog).
  class RepoEventChange {
    const RepoEventChange({required this.event, required this.docId, required this.fromInitialSnapshot});
    final RepoEvent event; final String docId; final bool fromInitialSnapshot;
  }
  /// Maps a Firestore document data map to a RepoEvent (null if no `repo`).
  RepoEvent? repoEventFromData(Map<String, dynamic> data);
  ```

- [ ] **Step 1: Add dependencies**

Run: `flutter pub add cloud_firestore firebase_auth`
Expected: `pubspec.yaml` gains `cloud_firestore` and `firebase_auth` at versions compatible with the existing `firebase_core: ^4.10.0`; `flutter pub get` succeeds.

- [ ] **Step 2: Write the failing test (model mapping)**

`test/features/realtime/data/repositories/realtime_repository_test.dart`:
```dart
// Test summary:
// - repoEventFromData maps a full document
// - repoEventFromData returns null when `repo` is missing
// - (Task 6) chunkRepos splits a list into <=30-sized batches
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_board/features/realtime/data/models/repo_event.dart';

void main() {
  group('repoEventFromData', () {
    test('maps a full document', () {
      final e = repoEventFromData({
        'repo': 'acme/web',
        'event': 'pull_request',
        'action': 'opened',
        'prNumber': 42,
      });
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/realtime/data/repositories/realtime_repository_test.dart`
Expected: FAIL — `repo_event.dart` / `repoEventFromData` not found.

- [ ] **Step 4: Implement the model**

`lib/features/realtime/data/models/repo_event.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'repo_event.freezed.dart';

/// A relay event: GitHub activity occurred on [repo]. Carries no PR contents.
@freezed
sealed class RepoEvent with _$RepoEvent {
  const factory RepoEvent({
    required String repo,
    required String event,
    String? action,
    int? prNumber,
  }) = _RepoEvent;
}

/// One Firestore docChange surfaced to the provider layer. [fromInitialSnapshot]
/// is true for documents already present on the first snapshot (the backlog we
/// suppress) and false for changes that arrive afterward.
class RepoEventChange {
  const RepoEventChange({
    required this.event,
    required this.docId,
    required this.fromInitialSnapshot,
  });

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
```

(No `fromJson`/`.g.dart` needed — Firestore mapping is hand-written via `repoEventFromData`, so the model only needs `.freezed.dart`.)

- [ ] **Step 5: Generate code**

Run: `dart run build_runner build -d`
Expected: emits `repo_event.freezed.dart`.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/realtime/data/repositories/realtime_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml lib/features/realtime/data/models/repo_event.dart test/features/realtime/data/repositories/realtime_repository_test.dart
git commit -m "feat(realtime): add cloud_firestore/firebase_auth deps + RepoEvent model

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Realtime repository (interface, Firestore impl, mock, `chunkRepos`)

**Files:**
- Create: `lib/features/realtime/data/repositories/realtime_repository.dart`
- Test: extend `test/features/realtime/data/repositories/realtime_repository_test.dart`

**Interfaces:**
- Consumes: `RepoEvent`, `RepoEventChange`, `repoEventFromData` (Task 5).
- Produces:
  ```dart
  abstract class RealtimeRepository {
    /// Emits batches of doc changes for the given repos. Empty repos -> empty stream.
    Stream<List<RepoEventChange>> watch(List<String> repos);
  }
  class FirestoreRealtimeRepository implements RealtimeRepository { FirestoreRealtimeRepository(this._db); ... }
  class MockRealtimeRepository implements RealtimeRepository {
    final _controller = StreamController<List<RepoEventChange>>.broadcast();
    void emit(List<RepoEventChange> changes); // test helper
  }
  /// Splits repos into <=size chunks (Firestore whereIn caps at 30).
  List<List<String>> chunkRepos(List<String> repos, {int size = 30});
  ```

- [ ] **Step 1: Write the failing test (chunkRepos)**

Append to `test/features/realtime/data/repositories/realtime_repository_test.dart` inside `main()`:
```dart
  group('chunkRepos', () {
    test('returns a single chunk when under the cap', () {
      expect(chunkRepos(['a', 'b', 'c']), [['a', 'b', 'c']]);
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
```
Add the import at the top of the file:
```dart
import 'package:turbo_board/features/realtime/data/repositories/realtime_repository.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/realtime/data/repositories/realtime_repository_test.dart`
Expected: FAIL — `chunkRepos` not found.

- [ ] **Step 3: Implement the repository**

`lib/features/realtime/data/repositories/realtime_repository.dart`:
```dart
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
      return _db
          .collection('repo_events')
          .where('repo', whereIn: chunk)
          .orderBy('ts')
          .snapshots()
          .map((snap) {
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
```

- [ ] **Step 4: Add `rxdart` dependency** (for `Rx.merge` of the per-chunk streams)

Run: `flutter pub add rxdart`
Expected: `rxdart` added (pure-Dart, all platforms); `flutter pub get` succeeds.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/realtime/data/repositories/realtime_repository_test.dart`
Expected: PASS (model + chunkRepos tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/realtime/data/repositories/realtime_repository.dart test/features/realtime/data/repositories/realtime_repository_test.dart pubspec.yaml
git commit -m "feat(realtime): RealtimeRepository (Firestore + mock) with whereIn chunking

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: `RealtimeListener` provider — suppression, debounce, invalidation

**Files:**
- Create: `lib/features/realtime/presentation/providers/realtime_provider.dart`
- Test: `test/features/realtime/presentation/providers/realtime_provider_test.dart`

**Interfaces:**
- Consumes: `RealtimeRepository`, `RepoEventChange`, `RepoEvent` (Tasks 5–6); `watchedReposProvider` (existing, `lib/features/repo_setup/presentation/providers/watched_repos_provider.dart`); `prInboxProvider`, `leadCockpitProvider`, `sprintReportProvider`, `projectsBoardProvider`, `prDetailProvider({owner,name,number})` (existing).
- Produces:
  ```dart
  enum RealtimeStatus { disabled, connecting, connected, error }
  @riverpod RealtimeRepository realtimeRepository(Ref ref);   // FirestoreRealtimeRepository(FirebaseFirestore.instance)
  @Riverpod(keepAlive: true) class RealtimeListener extends _$RealtimeListener {
    RealtimeStatus build();
  }
  // realtimeListenerProvider exposes RealtimeStatus.
  ```
- Behavior: ignore `fromInitialSnapshot` changes; dedup by docId within the session; debounce 3s, coalescing by repo (keep the latest event per repo); on flush, for each repo's event apply the mapping below.

**Event → provider invalidation mapping:**
| `event` | Invalidate |
|---|---|
| `pull_request` | `prInboxProvider`, `leadCockpitProvider`, `sprintReportProvider`, `projectsBoardProvider`, `prDetailProvider(owner,name,number)` |
| `pull_request_review` | `prInboxProvider`, `prDetailProvider(owner,name,number)` |
| `check_suite` | `prInboxProvider`, `prDetailProvider(owner,name,number)` |
| `issue_comment`, `pull_request_review_comment` | `prDetailProvider(owner,name,number)` only |

`prDetailProvider(...)` is invalidated only when `prNumber != null`; `owner`/`name` come from splitting `repo` on `/`.

- [ ] **Step 1: Write the failing test**

`test/features/realtime/presentation/providers/realtime_provider_test.dart`:
```dart
// Test summary:
// - backlog (fromInitialSnapshot) changes do NOT invalidate anything
// - a pull_request event invalidates the board (prInbox) after the debounce
// - a duplicate docId does not invalidate twice
// - issue_comment invalidates only the matching prDetail, not the board
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turbo_board/features/pr_detail/data/models/pr_detail.dart';
import 'package:turbo_board/features/pr_detail/presentation/providers/pr_detail_provider.dart';
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/features/pr_inbox/presentation/providers/pr_inbox_provider.dart';
import 'package:turbo_board/features/realtime/data/models/repo_event.dart';
import 'package:turbo_board/features/realtime/data/repositories/realtime_repository.dart';
import 'package:turbo_board/features/realtime/presentation/providers/realtime_provider.dart';
import 'package:turbo_board/features/repo_setup/presentation/providers/watched_repos_provider.dart';

RepoEventChange change(String event, {String repo = 'acme/web', int? pr, String id = 'd1', bool initial = false}) =>
    RepoEventChange(
      event: RepoEvent(repo: repo, event: event, prNumber: pr),
      docId: id,
      fromInitialSnapshot: initial,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'watched_repos': <String>['acme/web']}));

  ({ProviderContainer container, MockRealtimeRepository repo, int Function() board, int Function() detail42})
      makeContainer() {
    var board = 0;
    var detail42 = 0;
    final repo = MockRealtimeRepository();
    final container = ProviderContainer(
      overrides: [
        realtimeRepositoryProvider.overrideWithValue(repo),
        prInboxProvider.overrideWith((ref) async {
          board++;
          return <PrData>[];
        }),
        prDetailProvider(owner: 'acme', name: 'web', number: 42).overrideWith((ref) async {
          detail42++;
          throw UnimplementedError(); // value never read; we only count builds
        }),
      ],
    );
    // Keep targets alive so invalidation actually recomputes.
    container.listen(prInboxProvider, (_, _) {});
    container.listen(prDetailProvider(owner: 'acme', name: 'web', number: 42), (_, _) {});
    // Start the listener.
    container.listen(realtimeListenerProvider, (_, _) {});
    return (container: container, repo: repo, board: () => board, detail42: () => detail42);
  }

  void settle(FakeAsync a) => a.elapse(const Duration(milliseconds: 1));
  const debounce = Duration(seconds: 3);

  test('backlog changes do not invalidate', () {
    fakeAsync((async) {
      final c = makeContainer();
      addTearDown(c.container.dispose);
      settle(async);
      final base = c.board();
      c.repo.emit([change('pull_request', pr: 42, id: 'b1', initial: true)]);
      async.elapse(debounce);
      settle(async);
      expect(c.board(), base, reason: 'initial-snapshot backlog is suppressed');
    });
  });

  test('a pull_request event refetches the board after debounce', () {
    fakeAsync((async) {
      final c = makeContainer();
      addTearDown(c.container.dispose);
      settle(async);
      final base = c.board();
      c.repo.emit([change('pull_request', pr: 42, id: 'd1')]);
      async.elapse(debounce);
      settle(async);
      expect(c.board(), base + 1);
    });
  });

  test('a duplicate docId does not invalidate twice', () {
    fakeAsync((async) {
      final c = makeContainer();
      addTearDown(c.container.dispose);
      settle(async);
      c.repo.emit([change('pull_request', pr: 42, id: 'd1')]);
      async.elapse(debounce);
      settle(async);
      final after = c.board();
      c.repo.emit([change('pull_request', pr: 42, id: 'd1')]); // same id
      async.elapse(debounce);
      settle(async);
      expect(c.board(), after, reason: 'docId already handled this session');
    });
  });

  test('issue_comment invalidates only prDetail, not the board', () {
    fakeAsync((async) {
      final c = makeContainer();
      addTearDown(c.container.dispose);
      settle(async);
      final board0 = c.board();
      final detail0 = c.detail42();
      c.repo.emit([change('issue_comment', pr: 42, id: 'd9')]);
      async.elapse(debounce);
      settle(async);
      expect(c.board(), board0, reason: 'comments never touch the board');
      expect(c.detail42(), detail0 + 1, reason: 'the affected PR detail refetches');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/realtime/presentation/providers/realtime_provider_test.dart`
Expected: FAIL — `realtime_provider.dart` / `realtimeListenerProvider` not found.

- [ ] **Step 3: Implement the provider**

`lib/features/realtime/presentation/providers/realtime_provider.dart`:
```dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../lead_cockpit/presentation/providers/lead_cockpit_provider.dart';
import '../../../pr_detail/presentation/providers/pr_detail_provider.dart';
import '../../../pr_inbox/presentation/providers/pr_inbox_provider.dart';
import '../../../projects_board/presentation/providers/projects_board_provider.dart';
import '../../../repo_setup/presentation/providers/watched_repos_provider.dart';
import '../../../sprint_report/presentation/providers/sprint_report_provider.dart';
import '../../data/models/repo_event.dart';
import '../../data/repositories/realtime_repository.dart';

part 'realtime_provider.g.dart';

/// Connection state of the realtime relay. `auto_refresh` widens its polling
/// interval while [connected].
enum RealtimeStatus { disabled, connecting, connected, error }

const _debounce = Duration(seconds: 3);

@riverpod
RealtimeRepository realtimeRepository(Ref ref) => FirestoreRealtimeRepository(FirebaseFirestore.instance);

/// Subscribes to the relay for the watched repos and, on fresh events, fires a
/// targeted refetch of the affected providers. Kept alive at the app root
/// (watched in `TurboBoardApp`); rebuilds when the watched set changes.
///
/// - Backlog (`fromInitialSnapshot`) changes are ignored, and every docId is
///   handled at most once per session — so reconnects never replay events.
/// - Events are debounced and coalesced by repo, collapsing CI bursts into one
///   refetch per repo.
@Riverpod(keepAlive: true)
class RealtimeListener extends _$RealtimeListener {
  StreamSubscription<List<RepoEventChange>>? _sub;
  Timer? _debounceTimer;
  final Set<String> _seenDocIds = {};
  final Map<String, RepoEvent> _pending = {}; // repo -> latest pending event

  @override
  RealtimeStatus build() {
    final repos = ref.watch(watchedReposProvider);
    ref.onDispose(_teardown);
    if (repos.isEmpty) return RealtimeStatus.disabled;

    _sub = ref.watch(realtimeRepositoryProvider).watch(repos).listen(
          _onChanges,
          onError: (_) => state = RealtimeStatus.error,
        );
    return RealtimeStatus.connecting;
  }

  void _onChanges(List<RepoEventChange> changes) {
    if (state == RealtimeStatus.connecting) state = RealtimeStatus.connected;
    for (final c in changes) {
      if (c.fromInitialSnapshot) continue; // suppress backlog
      if (!_seenDocIds.add(c.docId)) continue; // already handled this session
      _pending[c.event.repo] = c.event; // coalesce by repo (latest wins)
    }
    if (_pending.isNotEmpty) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounce, _flush);
    }
  }

  void _flush() {
    final events = _pending.values.toList();
    _pending.clear();
    for (final e in events) {
      _invalidateFor(e);
    }
  }

  void _invalidateFor(RepoEvent e) {
    final touchesBoard = switch (e.event) {
      'pull_request' || 'pull_request_review' || 'check_suite' => true,
      _ => false,
    };
    if (touchesBoard) {
      ref.invalidate(prInboxProvider);
      if (e.event == 'pull_request') {
        ref.invalidate(leadCockpitProvider);
        ref.invalidate(sprintReportProvider);
        ref.invalidate(projectsBoardProvider);
      }
    }
    // Detail: any PR-scoped event refetches the exact PR if one is open.
    final number = e.prNumber;
    if (number != null) {
      final slash = e.repo.indexOf('/');
      if (slash > 0) {
        final owner = e.repo.substring(0, slash);
        final name = e.repo.substring(slash + 1);
        ref.invalidate(prDetailProvider(owner: owner, name: name, number: number));
      }
    }
  }

  void _teardown() {
    _debounceTimer?.cancel();
    _sub?.cancel();
  }
}
```

- [ ] **Step 4: Generate code**

Run: `dart run build_runner build -d`
Expected: emits `realtime_provider.g.dart`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/realtime/presentation/providers/realtime_provider_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/realtime/presentation/providers/realtime_provider.dart test/features/realtime/presentation/providers/realtime_provider_test.dart
git commit -m "feat(realtime): RealtimeListener provider with backlog suppression, debounce, targeted invalidation

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Stretch polling interval while realtime is connected

**Files:**
- Modify: `lib/shared/ui/providers/auto_refresh_provider.dart`
- Test: extend `test/shared/ui/providers/auto_refresh_provider_test.dart`

**Interfaces:**
- Consumes: `realtimeListenerProvider` → `RealtimeStatus` (Task 7), `refreshIntervalProvider` (existing).
- Produces: while `RealtimeStatus.connected`, the effective interval is `max(userInterval, realtimeFallbackInterval)`; otherwise the user interval. New const `realtimeFallbackInterval = 1200` (20 min).

- [ ] **Step 1: Write the failing test**

Append to `test/shared/ui/providers/auto_refresh_provider_test.dart` inside `main()`. Add imports:
```dart
import 'package:turbo_board/features/realtime/presentation/providers/realtime_provider.dart';
```
Test:
```dart
  test('stretches the interval to the realtime fallback while connected', () {
    fakeAsync((async) {
      var builds = 0;
      final container = ProviderContainer(
        overrides: [
          realtimeListenerProvider.overrideWith(() => _StubListener(RealtimeStatus.connected)),
          prInboxProvider.overrideWith((ref) async {
            builds++;
            return <PrData>[];
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(prInboxProvider, (_, _) {});

      container.read(autoRefreshProvider.notifier).didChangeAppLifecycleState(AppLifecycleState.resumed);
      settle(async);
      final base = builds;

      // At the user default (5m) nothing should tick yet — we're stretched to 20m.
      async.elapse(const Duration(seconds: refreshIntervalDefault));
      settle(async);
      expect(builds, base, reason: 'no tick before the stretched interval');

      async.elapse(const Duration(seconds: realtimeFallbackInterval - refreshIntervalDefault));
      settle(async);
      expect(builds, base + 1, reason: 'one tick at the stretched 20m interval');
    });
  });
```
Add this stub class at the bottom of the file (after `main`):
```dart
class _StubListener extends RealtimeListener {
  _StubListener(this._status);
  final RealtimeStatus _status;
  @override
  RealtimeStatus build() => _status;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/ui/providers/auto_refresh_provider_test.dart`
Expected: FAIL — `realtimeFallbackInterval` undefined / interval not stretched.

- [ ] **Step 3: Modify `auto_refresh_provider.dart`**

Add the import:
```dart
import '../../../features/realtime/presentation/providers/realtime_provider.dart';
```
Add the constant above the class:
```dart
/// While the realtime relay is connected, polling backs off to this interval
/// (20 min) as a safety net for repos without a configured webhook.
const int realtimeFallbackInterval = 1200;
```
Replace the interval read in `build()` (currently `_seconds = ref.watch(refreshIntervalProvider);`) with:
```dart
    final userInterval = ref.watch(refreshIntervalProvider);
    final connected = ref.watch(realtimeListenerProvider) == RealtimeStatus.connected;
    _seconds = connected && userInterval < realtimeFallbackInterval ? realtimeFallbackInterval : userInterval;
```

- [ ] **Step 4: Generate code** (provider dependency graph changed)

Run: `dart run build_runner build -d`
Expected: succeeds.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/shared/ui/providers/auto_refresh_provider_test.dart`
Expected: PASS (existing tests + the new one).

- [ ] **Step 6: Commit**

```bash
git add lib/shared/ui/providers/auto_refresh_provider.dart test/shared/ui/providers/auto_refresh_provider_test.dart
git commit -m "feat(refresh): stretch polling to 20m while realtime relay is connected

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Bootstrap — anonymous sign-in + start the listener at app root

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart:57`

**Interfaces:**
- Consumes: `realtimeListenerProvider` (Task 7).
- Produces: silent anonymous auth on boot (best-effort; failure degrades to polling-only); the listener is kept alive at app root.

- [ ] **Step 1: Add anonymous sign-in to `main.dart`**

Add the import:
```dart
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
```
After the existing `await Firebase.initializeApp(...);` line, add:
```dart
  // Silent anonymous auth gates Firestore reads of the realtime relay. Best
  // effort: on failure the app runs polling-only (see auto_refresh_provider).
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e, s) {
    developer.log('Anonymous sign-in failed; realtime disabled', error: e, stackTrace: s);
  }
```

- [ ] **Step 2: Watch the listener at app root**

In `lib/app.dart`, immediately after line 57 (`ref.watch(autoRefreshProvider);`), add:
```dart
    // Keep the realtime relay listener alive for the whole app session.
    ref.watch(realtimeListenerProvider);
```
Add the import near the other provider imports:
```dart
import 'features/realtime/presentation/providers/realtime_provider.dart';
```

- [ ] **Step 3: Verify analysis + full test suite**

Run: `dart analyze && flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/app.dart
git commit -m "feat(realtime): anonymous auth on boot + start relay listener at app root

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: In-app webhook setup instructions

**Files:**
- Modify: the repo-setup screen (find with `grep -rln "watchedRepos\|WatchedRepos" lib/features/repo_setup/presentation/view/`)
- Test: none (static informational UI).

**Interfaces:**
- Consumes: nothing. Pure presentation using Tether components (`TetherCard`, `context.appText`, `context.appColors`).

- [ ] **Step 1: Locate the setup screen**

Run: `grep -rln "class .*Screen\|WatchedRepos" lib/features/repo_setup/presentation/view/`
Pick the screen that lists/toggles watched repos (where the user manages repos).

- [ ] **Step 2: Add a "Enable realtime updates" instructions card**

Inside that screen's build, add a `TetherCard` (match the existing card usage in the file — read it first) containing this copy. Use `context.appText`/`context.appColors` for styling, no hardcoded colors:
```
Enable realtime updates

Add one webhook so the board updates within seconds instead of on the refresh
interval. Org-level covers every repo at once; otherwise add it per repo.

  • Org or repo  →  Settings → Webhooks → Add webhook
  • Payload URL:  https://<region>-turboboard-59499.cloudfunctions.net/githubWebhook
  • Content type: application/json
  • Secret:       (your project webhook secret)
  • Events:       Pull requests, Pull request reviews,
                  Pull request review comments, Check suites, Issue comments

Without a webhook a repo still updates on the normal refresh interval.
```
Render the payload URL in a selectable/monospace style (use the same approach the file already uses for code/URLs; if none, wrap in `SelectableText`).

- [ ] **Step 3: Verify format + analysis + tests**

Run: `dart format --line-length 120 --set-exit-if-changed . && dart analyze && flutter test`
Expected: zero files changed by format; analyze clean; tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/features/repo_setup/presentation/view
git commit -m "feat(repo_setup): in-app webhook setup instructions for realtime

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Deploy + live verification

**Files:** none (deploy + manual verify).

This task confirms the relay end-to-end. It requires Firebase CLI auth and a deploy; do these interactively.

- [ ] **Step 1: Set the webhook secret**

Run: `firebase functions:secrets:set WEBHOOK_SECRET` (paste a strong random value; reuse it in the GitHub webhook config).

- [ ] **Step 2: Deploy backend**

Run: `firebase deploy --only functions,firestore:rules,firestore:indexes`
Expected: `githubWebhook` URL printed; rules + index deployed. Note the function URL.

- [ ] **Step 3: Configure the GitHub webhook**

In the org (or a test repo) Settings → Webhooks → Add webhook: Payload URL = the deployed function URL, content type `application/json`, secret = the value from Step 1, events = Pull requests, Pull request reviews, Pull request review comments, Check suites, Issue comments. Save.

- [ ] **Step 4: Verify a delivery writes an event**

Trigger activity (e.g. open/label a PR in a watched repo). In Firebase console → Firestore, confirm a `repo_events` doc appears with `{repo, event, action, prNumber, ts, expireAt}` and doc id = the GitHub delivery id (visible in the webhook's Recent Deliveries). GitHub should show a `204` response.

- [ ] **Step 5: Verify the client refetches**

Run the app (`flutter run -d macos`), watch a repo, trigger a PR event, and confirm the board updates within a few seconds without a manual refresh. Then confirm an invalid-signature POST is rejected (GitHub's "Redeliver" with a tampered secret, or `curl` with a bad signature → `401`).

- [ ] **Step 6: Final full check**

Run: `dart format --line-length 120 --set-exit-if-changed . && dart analyze && flutter test && (cd functions && npm run build && npx vitest run)`
Expected: all green.

---

## Self-Review Notes

- **Spec coverage:** relay handler (T3) + HMAC (T1) + mapping (T2) + Firestore rules/TTL/index (T4) + anonymous auth (T9) + model (T5) + repository with chunking & backlog tagging (T6) + provider with suppression/debounce/global-prInbox + event mapping (T7) + stretched-poll fallback (T8) + setup docs (T10) + deploy/verify (T11). All spec sections mapped.
- **Backlog suppression** lives in the repository (tags `fromInitialSnapshot`) + provider (drops them, dedups docId) per the spec's "docChanges-after-first-snapshot, dedup by docId" decision — testable via `MockRealtimeRepository` without a fake Firestore.
- **`prInbox` stays global** (one query, all repos) per the approved decision; comments (`issue_comment`/`review_comment`) never invalidate it.
- **TTL:** `expireAt` is written by the function (T3); enable the Firestore TTL policy on `expireAt` in the Firebase console (one-time console action — noted here as it is console-only, not code).
- **Type consistency:** `RealtimeStatus`, `RepoEvent`, `RepoEventChange`, `chunkRepos`, `repoEventFromData`, `realtimeListenerProvider`, `realtimeRepositoryProvider`, `realtimeFallbackInterval` used identically across tasks.
