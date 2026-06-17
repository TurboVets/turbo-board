import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version_provider.g.dart';

/// The app's semantic version (e.g. `0.1.1`), read from the bundle metadata —
/// which is generated from `pubspec.yaml`'s `version:` at build time, so this is
/// the single source of truth. Build number is dropped for display.
@Riverpod(keepAlive: true)
Future<String> appVersion(Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}
