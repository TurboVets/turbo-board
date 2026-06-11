#!/usr/bin/env bash
# One-time project setup. Run from the repo root:
#   bash scripts/setup.sh
set -euo pipefail

# 1. Generate platform runners (desktop + tablet + web; phones not a target,
#    but android/ios are included for tablet builds).
flutter create . --project-name turbo_board \
  --platforms=macos,windows,linux,web,android,ios

# 2. Dependencies
flutter pub get

# 3. Code generation (Freezed, JsonSerializable, Riverpod)
dart run build_runner build -d

# 4. Quality gates
dart format --line-length 120 .
dart analyze
flutter test

echo "Setup complete. Run with: flutter run -d macos (or -d chrome)"
