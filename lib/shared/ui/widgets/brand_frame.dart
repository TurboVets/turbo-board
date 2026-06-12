import 'package:flutter/material.dart';

import '../theme/tb_tokens.dart';

/// Wraps the whole app in the Tether brand chrome: a faint 46px grid canvas,
/// a thin blue top rail and Shiraz-red bottom rail, each with square end-caps.
class BrandFrame extends StatelessWidget {
  const BrandFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TbColors.appBg,
      child: Stack(
        children: [
          // Grid canvas behind everything.
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
              child: const ColoredBox(color: TbColors.canvas),
            ),
          ),
          // Content, inset by the 2px rails.
          Positioned.fill(top: 2, bottom: 2, child: child),
          // Top blue rail + end-caps.
          const _Rail(top: true, gradient: [TbColors.navy, TbColors.blueBright, TbColors.navy], cap: TbColors.blue),
          // Bottom Shiraz rail + end-caps.
          const _Rail(
            top: false,
            gradient: [TbColors.shirazDeep, TbColors.shiraz, TbColors.shirazDeep],
            cap: TbColors.shiraz,
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.top, required this.gradient, required this.cap});

  final bool top;
  final List<Color> gradient;
  final Color cap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient, stops: const [0, 0.5, 1]),
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(left: 10, top: -3, child: _Cap(cap)),
          Positioned(right: 10, top: -3, child: _Cap(cap)),
        ],
      ),
    );
  }
}

class _Cap extends StatelessWidget {
  const _Cap(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(width: 8, height: 8, child: ColoredBox(color: color));
}

class _GridPainter extends CustomPainter {
  static const _cell = 46.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0x09FFFFFF) // slightly stronger than .018 so it survives compositing
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
