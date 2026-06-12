import 'package:flutter/material.dart';

import 'package:turbo_board/shared/ui/theme/tb_tokens.dart';

/// The "Viewfinder T" brand mark (SVG viewBox 0 0 32 32): gray corner brackets
/// framing a blue "T", with a Shiraz-red target dot.
///
/// Pass [muted] for the monochrome watermark variant used in empty states —
/// darker brackets, a dim grey "T", and no red dot.
class TurboMark extends StatelessWidget {
  const TurboMark({super.key, this.size = 30, this.muted = false});

  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TurboMarkPainter(muted: muted),
    size: Size.square(size),
  );
}

class _TurboMarkPainter extends CustomPainter {
  _TurboMarkPainter({required this.muted});

  final bool muted;

  static const _bracket = Color(0xFF5C5C5C);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 32;
    final sy = size.height / 32;

    void r(Paint paint, double x, double y, double w, double h) =>
        canvas.drawRect(Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy), paint);

    // Corner brackets — "everything watched, in one frame".
    final bracket = Paint()..color = muted ? TbColors.borderStrong : _bracket;
    r(bracket, 3, 3, 7, 2); // top-left ─
    r(bracket, 3, 3, 2, 7); // top-left │
    r(bracket, 22, 3, 7, 2); // top-right ─
    r(bracket, 27, 3, 2, 7); // top-right │
    r(bracket, 3, 27, 7, 2); // bottom-left ─
    r(bracket, 3, 22, 2, 7); // bottom-left │
    r(bracket, 22, 27, 7, 2); // bottom-right ─
    r(bracket, 27, 22, 2, 7); // bottom-right │

    // The "T" centered in the frame.
    final stem = Paint()..color = muted ? TbColors.dim : TbColors.blue;
    r(stem, 10, 10, 12, 3); // crossbar
    r(stem, 14.5, 10, 3, 12); // stem

    // Shiraz-red target dot — full-colour variant only.
    if (!muted) r(Paint()..color = TbColors.shiraz, 19.5, 19, 2.5, 2.5);
  }

  @override
  bool shouldRepaint(covariant _TurboMarkPainter oldDelegate) => oldDelegate.muted != muted;
}
