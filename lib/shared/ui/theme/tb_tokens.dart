import 'package:flutter/widgets.dart';

/// TurboBoard design tokens — verbatim from the Tether v2.0 design
/// (`TurboBoard.dc.html`). These exact values drive the brand-matched UI;
/// widgets that must match the design pixel-for-pixel use these directly
/// rather than the broader turbo_ui theme.
abstract final class TbColors {
  // Canvas / surfaces
  static const appBg = Color(0xFF0B0B0C); // outermost background
  static const railBg = Color(0xFF0A0A0B); // left nav rail
  static const canvas = Color(0xFF18181B); // primary content background (grid)
  static const surface = Color(0xFF1E1E21); // cards / panels
  static const surface2 = Color(0xFF27272A); // raised / headers

  // Borders
  static const border = Color(0xFF303036);
  static const borderStrong = Color(0xFF45454C);

  // Text
  static const text = Color(0xFFF4F4F6);
  static const muted = Color(0xFFA6A6AD);
  static const dim = Color(0xFF6E6E76);

  // Brand
  static const blue = Color(0xFF0073FF);
  static const blueBright = Color(0xFF008BFF);
  static const cyan = Color(0xFF13ACFF);
  static const navy = Color(0xFF0A3161);
  static const shiraz = Color(0xFFB11C3B);
  static const shirazDeep = Color(0xFF480919);

  // Grid texture line color
  static const grid = Color(0x05FFFFFF); // rgba(255,255,255,.018)
}

/// A signal chip recipe: deep background, bright border, pale text.
class TbSignal {
  const TbSignal(this.bg, this.border, this.text);
  final Color bg;
  final Color border;
  final Color text;

  static const ok = TbSignal(Color(0xFF10280B), Color(0xFF54AE39), Color(0xFFCEEFC3));
  static const warn = TbSignal(Color(0xFF3D2A00), Color(0xFFFFB000), Color(0xFFFFE58A));
  static const bad = TbSignal(Color(0xFF480919), Color(0xFFE94A5F), Color(0xFFFBD0D3));
  static const info = TbSignal(Color(0xFF0A3161), Color(0xFF13ACFF), Color(0xFFB2EBFF));
  static const gray = TbSignal(Color(0xFF27272A), Color(0x73BABBBF), Color(0xFFDADADD));
  static const orange = TbSignal(Color(0xFF421406), Color(0xFFFF5A1F), Color(0xFFFFC2A3));
}

/// Per-column top-accent colors for the PR board.
abstract final class TbBoard {
  static const needsReview = Color(0xFF13ACFF);
  static const changesRequested = Color(0xFFE94A5F);
  static const approved = Color(0xFF54AE39);
  static const waiting = Color(0xFF45454C);
}

/// Deterministic avatar background for an author login, plus the standard
/// signal-dot colors used for repos. Mirrors the design's `AV` map but works
/// for any login via a stable hash.
abstract final class TbAvatar {
  static const _palette = [
    Color(0xFF0A3161),
    Color(0xFF1F3A5F),
    Color(0xFF5A3A1A),
    Color(0xFF1A4D33),
    Color(0xFF5C1424),
  ];

  static Color bgFor(String login) {
    if (login.isEmpty) return _palette.first;
    var hash = 0;
    for (final unit in login.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return _palette[hash % _palette.length];
  }

  static String initials(String login) {
    final clean = login.trim();
    if (clean.isEmpty) return '?';
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }
}

/// Stable repo signal-dot color from the repo slug.
abstract final class TbRepoColor {
  static const _palette = [
    Color(0xFF54AE39),
    Color(0xFF0073FF),
    Color(0xFFFFB000),
    Color(0xFFE94A5F),
    Color(0xFFBABBBF),
  ];

  static Color forSlug(String slug) {
    if (slug.isEmpty) return _palette.last;
    var hash = 0;
    for (final unit in slug.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return _palette[hash % _palette.length];
  }
}
