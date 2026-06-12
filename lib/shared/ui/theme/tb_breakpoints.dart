import 'package:flutter/widgets.dart';

/// Responsive breakpoints for TurboBoard.
///
/// - Below [mobile] (640px): phone layout — the nav rail is replaced by a fixed
///   bottom tab bar and multi-column boards collapse to a single column.
/// - Between [mobile] and [tablet]: the nav rail collapses to icons.
/// - At or above [tablet]: the full expanded rail.
abstract final class TbBreakpoints {
  /// Phone layout below this width (matches the design mockup's `w < 640`).
  static const double mobile = 640;

  /// Rail collapses to icon-only below this width (tablet landscape).
  static const double tablet = 1100;
}

/// Convenience width queries off the ambient [MediaQuery]. Prefer a
/// `LayoutBuilder` when reacting to the local content box (e.g. inside a drawer),
/// and these when reacting to the window/screen size.
extension TbResponsive on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isMobile => screenWidth < TbBreakpoints.mobile;
  bool get isTablet => screenWidth >= TbBreakpoints.mobile && screenWidth < TbBreakpoints.tablet;
  bool get isDesktop => screenWidth >= TbBreakpoints.tablet;
}
