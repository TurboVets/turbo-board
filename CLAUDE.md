# AI Agent Rules for TurboBoard

This document provides guidelines for AI agents (Claude, Cursor, etc.) working on the TurboBoard Flutter application.

## Project Overview

**Type:** GitHub PR dashboard application (Flutter/Dart)
**Architecture:** Clean Architecture with feature-based modular organization
**State Management:** Riverpod with code generation
**Backend:** GitHub REST/GraphQL API via turbo_core network clients
**Design System:** Tether Design System v2.0 via turbo_ui
**Target Platforms:** macOS, Windows, Linux, Web, and tablets (iPad / Android tablet). **Phones are NOT a target form factor.**

**Design reference:** `design/mockup.html` is the interactive HTML mockup of all screens (PR Inbox board, Needs Attention, PR Detail, filters) built with verified Tether tokens — open it in a browser or read the HTML/CSS directly for layout, spacing, and color decisions. `design/README.md` documents the design direction and token tables. Product scope: `docs/V1-SCOPE.md`; AI features: `docs/AI-FEATURES.md`.

## Core Principles

1. **Read before writing** - Always read existing files before making changes
2. **Follow existing patterns** - Match the established architecture and coding style
3. **Generate code when needed** - Run build_runner after model/provider changes
4. **Test your changes** - Write tests for new features and bug fixes
5. **Respect the architecture** - Maintain the data/presentation layer separation
6. **Cross-platform first** - Every package and API must work on desktop, tablet, AND web

---

## Pre-Completion Checklist

Before considering any feature, fix, or change complete, run these checks
and fix any failures:

### 1. Format check (required — CI will reject unformatted code)

```bash
dart format --line-length 120 --set-exit-if-changed .
```

If files are reported as changed, fix them with `dart format --line-length 120 .`
then re-run the check to confirm zero changed files.

### 2. Static analysis

```bash
dart analyze
```

### 3. Tests (when applicable)

```bash
flutter test
```

---

## Platform Rules (read this before adding any package)

TurboBoard builds for **macos, windows, linux, web, android, ios** (android/ios for tablets only).

1. **Verify platform support on pub.dev before adding a dependency.** A package must support all six platforms (or be replaceable with a conditional import for web).
2. **Avoid mobile-only plugins** — camera/scanner, firebase_crashlytics, push notifications, etc.
3. **Depend on `turbo_core` + `turbo_ui` directly, never the `turbo_sdk` umbrella.** `turbo_services` and `turbo_task` pull in mobile-only plugins (cunning_document_scanner, firebase_crashlytics) that break desktop/web builds.
4. **No `dart:io` in shared code paths** without a web fallback (`kIsWeb` check or conditional imports).
5. **Design for pointer + keyboard first**, touch second. Minimum window/layout width assumption: ~840px (tablet landscape). Do not build phone layouts.
6. **Web caveats:** flutter_secure_storage uses WebCrypto on web (keys don't survive browser data clears); direct GitHub API calls may need CORS handling.

---

## Architecture Patterns

### Feature Structure

Each feature follows this structure:
```
lib/features/feature_name/
├── data/
│   ├── models/           # Freezed models with JSON serialization
│   ├── queries/          # GitHub GraphQL queries / REST request builders
│   ├── repositories/     # Data access layer
│   └── services/         # Service implementations
└── presentation/
    ├── providers/        # Riverpod providers
    ├── view/             # UI widgets and screens
    ├── view_models/      # UI State model
    └── helpers/          # Presentation utilities
```

Current/planned features: `pr_inbox`, `pr_detail`, `repo_setup` (auth + watched repos), `ai` (BYOK Anthropic features).

### Adding New Features

When creating a new feature:

1. **Create the feature directory structure** under `lib/features/`
2. **Start with data layer:**
   - Define models in `data/models/` using Freezed
   - Create GitHub queries in `data/queries/`
   - Implement repository in `data/repositories/` (interface + implementation, so tests and mock mode can substitute)
3. **Build presentation layer:**
   - Create providers in `presentation/providers/`
   - Build UI in `presentation/view/`
   - Add view models if complex state is needed
4. **Update routing** in `lib/shared/router/`
5. **Run code generation:**
   ```bash
   dart run build_runner build -d
   ```

### Example: Creating a Model

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'my_model.freezed.dart';
part 'my_model.g.dart';

@freezed
sealed class MyModel with _$MyModel {
  const factory MyModel({
    required String id,
    required String name,
    String? description,
    @Default([]) List<String> tags,
  }) = _MyModel;

  factory MyModel.fromJson(Map<String, dynamic> json) => _$MyModelFromJson(json);
}
```

**Key points:**
- Use `@freezed` annotation with `sealed class`
- Include part directives for generated files
- Use factory constructor with named parameters
- Add `fromJson` factory for JSON deserialization
- Use `@Default()` for default values
- Prefer immutable collections

---

## State Management

### When to Use Hooks vs Riverpod

The project uses **two complementary state management approaches**:

#### Use Flutter Hooks for Local State
Use `flutter_hooks` with `HookWidget` or `HookConsumerWidget` for:
- **UI state** - Loading indicators, text field values, form state
- **Local animations** - Animation controllers, tween values
- **Temporary state** - Modal dialogs, bottom sheets, expansion states
- **Component-specific state** - State that doesn't need to be shared

#### Use Riverpod for Remote/Scope/Global State
Use Riverpod providers for:
- **Remote data** - GitHub API calls, Anthropic API calls
- **Global state** - Auth tokens, watched repos, app settings
- **Shared state** - State accessed by multiple screens/widgets (e.g. active filters)
- **Business logic** - Complex state that requires testing
- **Computed state** - Derived values from other providers (e.g. filtered/sorted PR list)

```dart
// Remote/API state
@riverpod
Future<List<PrData>> prInbox(Ref ref) async {
  final repo = ref.watch(prInboxRepositoryProvider);
  final result = await repo.fetchOpenPrs();
  return switch (result) {
    ResultSuccess(:final data) => data,
    ResultFailure(:final message) => throw Exception(message),
  };
}

// Global state
@Riverpod(keepAlive: true)
class WatchedReposNotifier extends _$WatchedReposNotifier {
  @override
  List<String> build() => const [];
}
```

**Rule of thumb:** If the state is only needed within a single widget tree and doesn't involve data fetching, use hooks. If it's shared across widgets or involves API calls, use Riverpod.

### Provider Guidelines

1. **Use `keepAlive: true`** for providers that should persist (auth, routing, repositories, global state)
2. **Use lowercase `@riverpod`** for auto-dispose providers (temporary data, UI state)
3. **Pass parameters** to providers rather than using global state
4. **Watch dependencies** using `ref.watch()` in build method
5. **Invalidate providers** when data changes:
   ```dart
   ref.invalidate(prInboxProvider);
   ```
6. **Use `.notifier`** to access state modification methods:
   ```dart
   ref.read(watchedReposNotifierProvider.notifier).add(repo);
   ```

### State Classes with Freezed

Use sealed unions for state that has multiple variants, and pattern matching
(`switch` expressions) in widgets/providers to consume them.

---

## Code Generation Workflow

### When to Run Build Runner

Run code generation after:
- Creating or modifying Freezed models
- Adding or changing Riverpod providers
- Updating JSON serialization annotations
- Generating mocks for tests

### Commands

**Standard build (recommended):**
```bash
dart run build_runner build -d
```

**Watch mode for development:**
```bash
dart run build_runner watch -d
```

**Clean build (if issues occur):**
```bash
dart run build_runner clean
dart run build_runner build -d
```

### Generated Files

Never edit generated files directly:
- `*.freezed.dart` - Freezed models
- `*.g.dart` - JSON serialization and Riverpod providers
- `*.mocks.dart` - Test mocks

These files are ignored by git via `.gitignore` but must be generated locally and in CI/CD.

---

## Testing Requirements

### Test Structure

Place tests in `test/` directory mirroring `lib/` structure:
```
test/
└── features/
    └── pr_inbox/
        ├── data/
        │   └── repositories/
        │       └── pr_inbox_repository_test.dart
        └── presentation/
            └── providers/
                └── pr_inbox_provider_test.dart
```

### Testing Guidelines

1. **Generate mocks** using `@GenerateMocks` annotation (mockito)
2. **Use ProviderContainer** for isolated provider testing
3. **Override providers** for dependency injection
4. **Test all state transitions** in state notifiers
5. **Test error handling** - don't just test happy paths
6. **Use descriptive test names** - "should [expected behavior] when [condition]"
7. **Follow AAA pattern** - Arrange, Act, Assert
8. **Clean up resources** in tearDown()
9. **Test summary** - write a test summary at the top of the test file, listing all test cases covered

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/features/pr_inbox/data/repositories/pr_inbox_repository_test.dart

# Run with coverage
flutter test --coverage
```

---

## GitHub API Integration

Use turbo_core's network clients (`DioClient`, `GraphQLClient`) — do not hand-roll HTTP clients.

### Query Structure

Place GitHub GraphQL queries / REST builders in `data/queries/` with descriptive names:

```dart
// lib/features/pr_inbox/data/queries/search_open_prs.dart
const String searchOpenPrsQuery = '''
  query SearchOpenPrs(\$searchQuery: String!, \$first: Int!) {
    search(query: \$searchQuery, type: ISSUE, first: \$first) {
      nodes {
        ... on PullRequest {
          number
          title
          isDraft
          updatedAt
          reviewDecision
          repository { nameWithOwner }
        }
      }
    }
  }
''';
```

### Error Handling

Handle errors using `try catch` inside the repo layer **only**.
Above the repo layer, errors are represented by the `Result<T>` type (from turbo_core) returned from repositories:

```dart
try {
  final data = await client.request(...);
  return Result.success(data);
} catch (e, stackTrace) {
  log('Unexpected error', error: e, stackTrace: stackTrace);
  return Result.failure('Something went wrong', stackTrace);
}
```

### Secrets

- GitHub tokens and Anthropic API keys (BYOK) are stored with `flutter_secure_storage` only
- **Never** hardcode, log, or commit tokens/keys
- Validate keys/tokens with a cheap test call on entry

---

## Navigation and Routing

### Adding Routes

When creating a new screen, add a static route name to the class:

```dart
class MyFeatureScreen extends StatelessWidget {
  static const String routeName = 'myFeature';
}
```

Update `lib/shared/router/app_router.dart`:

```dart
GoRoute(
  path: '/my-feature/:id',
  name: MyFeatureScreen.routeName,
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return MyFeatureScreen(id: id);
  },
)
```

### Navigation Best Practices

1. **Use named routes** with `context.goNamed(MyFeatureScreen.routeName)`
2. **Pass parameters** via path parameters or extra data
3. **Check auth state** in redirect callbacks
4. **Use shell routes** for the persistent app shell (nav rail + content)
5. **Keep web URLs meaningful** — this app runs in browsers; deep links like `/repo/owner/name/pr/42` should work on refresh

---

## UI and Styling

### Tether Design System (turbo_ui)

The app theme is built with `getTetherThemeData()` from turbo_ui (see `lib/shared/ui/theme/app_theme.dart`). TurboBoard is **dark-first**.

Access tokens in widgets:

```dart
// Via BuildContext extension (recommended)
final colors = context.appColors;   // TetherAppColors
final text = context.appText;       // TetherAppText

// Material fallbacks (mapped to Tether tokens by the theme)
final colorScheme = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;
```

**Prefer Tether components** from turbo_ui before writing custom ones: `TetherCard`, `TetherActionButton`, `TetherIconButton`, `TetherSegmentedButtonGroup`, `TetherBadge`, `TetherSignalDot`, `TetherListItem`, `TetherAppBar`, `TetherTextField`, popovers/modals, etc. (see `turbo_ui/lib/src/tether_design/components/`). Read the component source for its API before using it.

Status signal mapping (PR dashboard semantics):
- CI passing / approved → green signal
- CI pending → yellow/amber signal
- CI failing / changes requested → red signal
- Needs review / draft info → blue signal
- Waiting / draft → gray signal
- Stale → orange signal

### Responsive Design

Desktop-first, tablet-friendly. No phone layouts.

```dart
// Use LayoutBuilder for adaptive widgets
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 1100) {
      return TabletLayout();   // collapsed rail, single column + drawer detail
    }
    return DesktopLayout();    // rail + board + detail/filter column
  },
)
```

### Widget Types

Decision tree:
1. Does it need Riverpod? Does it need local state/hooks?
   - **No + No** → `StatelessWidget`
   - **Yes + No** → `ConsumerWidget`
   - **No + Yes** → `HookWidget`
   - **Yes + Yes** → `HookConsumerWidget` (most common for screens)

### Custom Widgets

Place shared widgets in `lib/shared/ui/`:
```
lib/shared/ui/
├── theme/
└── widgets/
```

---

## Things to Avoid

1. **Don't use StatefulWidget for local state** - Prefer `HookWidget` or `HookConsumerWidget` with flutter_hooks
2. **Don't use Riverpod for UI-only state** - Use hooks for local state (text fields, animations, expansion states)
3. **Don't bypass the repository layer** - Always access data through repositories
4. **Don't add mobile-only packages** - Every dependency must build on desktop, tablet, and web
5. **Don't depend on turbo_sdk** - Use turbo_core + turbo_ui directly (see Platform Rules)
6. **Don't hardcode strings** - Use constants or localization
7. **Don't ignore null safety** - Properly handle nullable types
8. **Don't create mutable state** - Use Freezed for immutable models
9. **Don't use global variables** - Use providers for shared state
10. **Don't skip code generation** - Always run build_runner after changes
11. **Don't commit generated files** - They are generated locally and in CI/CD
12. **Don't log or commit secrets** - GitHub tokens and API keys live in secure storage only
13. **Don't over-engineer** - Follow YAGNI (You Aren't Gonna Need It)

---

## CI/CD and Pull Requests

### Pre-PR Checklist

Before submitting a PR:

1. **Run code generation:** `dart run build_runner build -d`
2. **Check formatting:** `dart format --line-length 120 --set-exit-if-changed .`
3. **Run analysis:** `dart analyze`
4. **Run tests:** `flutter test`
5. **Verify on at least two targets:** one desktop (`flutter run -d macos`) and web (`flutter run -d chrome`)

### PR Guidelines

- **Write descriptive titles** - Include ticket number when applicable
- **Describe changes** - Explain what and why, not just what
- **Add screenshots** - For UI changes
- **Keep PRs focused** - One feature/fix per PR

### Commits

Use Conventional Commits format — `feat(scope):`, `fix(scope):`, `chore(scope):`. Breaking changes use `!` suffix.

---

## File Naming Conventions

- **Features:** `lowercase_with_underscores`
- **Files:** `lowercase_with_underscores.dart`
- **Screens:** `feature_screen.dart`
- **Widgets:** `feature_widget.dart`
- **Providers:** `feature_provider.dart`
- **Models:** `feature_model.dart`
- **Repositories:** `feature_repository.dart`
- **Services:** `feature_service.dart`

---

## Import Organization

Order imports as follows:

```dart
// 1. Dart SDK imports
import 'dart:async';
import 'dart:developer';

// 2. Flutter imports
import 'package:flutter/material.dart';

// 3. Package imports (alphabetically)
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// 4. Local imports (alphabetically)
import 'package:turbo_board/features/pr_inbox/data/models/pr_data.dart';
import 'package:turbo_board/shared/ui/theme/app_theme.dart';

// 5. Part directives (at end)
part 'my_file.freezed.dart';
part 'my_file.g.dart';
```

---

## Resources

- **Flutter:** https://docs.flutter.dev/
- **Riverpod:** https://riverpod.dev/
- **Freezed:** https://pub.dev/packages/freezed
- **GoRouter:** https://pub.dev/packages/go_router
- **GitHub GraphQL API:** https://docs.github.com/en/graphql
- **Shared components / Tether:** https://github.com/TurboVets/mobile-shared-components

---

**Remember:** When in doubt, follow existing patterns in the codebase (and in `mobile_recruit`, which this project mirrors). Consistency is more valuable than perfection.
