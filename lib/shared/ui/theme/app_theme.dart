import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turbo_ui/turbo_ui.dart';

import 'tb_tokens.dart';

/// App-wide theme built on the Tether Design System (turbo_ui), brand-matched
/// to the TurboBoard design: Inclusive Sans body type, dark canvas, and a
/// transparent scaffold so the [BrandFrame] grid shows through.
///
/// TurboBoard is dark-first; both modes are provided but the app pins dark.
ThemeData getAppTheme({Brightness brightness = Brightness.dark}) {
  final colors = brightness == Brightness.light ? TetherAppColors.light : TetherAppColors.dark;
  final base = getTetherThemeData(appColor: colors, brightness: brightness);

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    textTheme: GoogleFonts.inclusiveSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: TbColors.text, displayColor: TbColors.text),
  );
}
