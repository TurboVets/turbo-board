import 'package:flutter/material.dart';
import 'package:turbo_ui/turbo_ui.dart';

/// App-wide theme built on the Tether Design System (turbo_ui).
///
/// TurboBoard is dark-first (dashboard app), but both modes are provided.
ThemeData getAppTheme({Brightness brightness = Brightness.dark}) {
  final colors = brightness == Brightness.light ? TetherAppColors.light : TetherAppColors.dark;

  return getTetherThemeData(appColor: colors, brightness: brightness);
}
