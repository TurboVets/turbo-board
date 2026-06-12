import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tb_tokens.dart';

/// Typography for the TurboBoard brand UI.
///
/// - **Inclusive Sans** for body/UI text (−1% tracking).
/// - **Akshar** for uppercase display, labels and metadata.
///
/// Helpers return [TextStyle]s with the design's exact sizes/tracking so call
/// sites stay terse and consistent.
abstract final class TbText {
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = TbColors.text,
    double height = 1.45,
  }) =>
      GoogleFonts.inclusiveSans(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: -0.14);

  /// Akshar — uppercase labels/metadata. [tracking] is letter-spacing in px.
  static TextStyle label({
    double size = 11,
    FontWeight weight = FontWeight.w600,
    Color color = TbColors.text,
    double tracking = 1.1,
    bool upper = true,
  }) => GoogleFonts.akshar(fontSize: size, fontWeight: weight, color: color, letterSpacing: tracking);

  /// Akshar display (e.g. the TURBO wordmark, screen titles).
  static TextStyle display({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color color = TbColors.text,
    double tracking = 2.0,
  }) => GoogleFonts.akshar(fontSize: size, fontWeight: weight, color: color, letterSpacing: tracking);
}
