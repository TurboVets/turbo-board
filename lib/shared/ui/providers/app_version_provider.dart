import 'dart:developer';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version_provider.g.dart';

/// Fallback shown if [PackageInfo] can't be read. Keep in sync with
/// `pubspec.yaml`'s `version:` (bumped together each release).
const String kAppVersionFallback = '0.2.0';

/// The app's semantic version (e.g. `0.1.2`), read from the bundle metadata —
/// generated from `pubspec.yaml`'s `version:` at build time, so that's the
/// single source of truth. Build number is dropped for display.
///
/// On web, `package_info_plus` fetches `version.json` relative to a base URL it
/// derives from the engine. On a deep route in a release build that base can be
/// scheme-less, which makes the plugin throw (its origin lookup fails) and
/// leaves the version blank. Passing an absolute `baseUrl` (the page origin)
/// makes it fetch `/version.json` directly and avoids that path. Any remaining
/// failure falls back to [kAppVersionFallback] so the version always renders.
@Riverpod(keepAlive: true)
Future<String> appVersion(Ref ref) async {
  try {
    final info = await PackageInfo.fromPlatform(baseUrl: kIsWeb ? '${Uri.base.origin}/' : null);
    if (info.version.isNotEmpty) return info.version;
  } catch (e, st) {
    log('appVersion: failed to read PackageInfo', error: e, stackTrace: st);
  }
  return kAppVersionFallback;
}
