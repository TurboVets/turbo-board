// lib/features/sprint_report/presentation/view/widgets/burndown_chart.dart
import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../data/models/sprint_report.dart';

/// Sprint burndown: remaining story points vs the ideal run-rate. The ideal
/// line + today marker are always live; the actual line is shown only in
/// "target" mode (until daily snapshots accrue).
class BurndownChart extends StatelessWidget {
  const BurndownChart({super.key, required this.data, required this.showActual});

  final Burndown data;
  final bool showActual;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 600 / 230,
      child: CustomPaint(painter: _BurndownPainter(data, showActual)),
    );
  }
}

class _BurndownPainter extends CustomPainter {
  _BurndownPainter(this.d, this.showActual);

  final Burndown d;
  final bool showActual;

  static const _padL = 36.0;
  static const _padR = 8.0;
  static const _padT = 12.0;
  static const _padB = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(_padL, _padT, size.width - _padR, size.height - _padB);
    final committed = d.committedPoints.toDouble();

    double xFor(double day) => plot.left + (day / d.totalDays) * plot.width;
    double yFor(double pts) => plot.bottom - (pts / committed) * plot.height;

    final labelStyle = TbText.label(size: 9, weight: FontWeight.w400, color: TbColors.dim, tracking: 0.2);

    // ── Horizontal gridlines + y labels (committed, 75%, 50%, 25%, 0) ──
    for (var i = 0; i <= 4; i++) {
      final frac = i / 4;
      final y = plot.top + frac * plot.height;
      final pts = (committed * (1 - frac)).round();
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()
          ..color = i == 4 ? TbColors.border : TbColors.surface2
          ..strokeWidth = 1,
      );
      _text(canvas, '$pts', Offset(plot.left - 6, y), labelStyle, alignRight: true, vCenter: true);
    }

    // ── X labels every 2 days ──
    for (var day = 0; day <= d.totalDays; day += 2) {
      _text(canvas, 'D$day', Offset(xFor(day.toDouble()), plot.bottom + 4), labelStyle, hCenter: true);
    }

    // ── Ideal line (dashed diagonal) ──
    _dashedLine(
      canvas,
      Offset(xFor(0), yFor(committed)),
      Offset(xFor(d.totalDays.toDouble()), yFor(0)),
      Paint()
        ..color = TbColors.borderStrong
        ..strokeWidth = 1.5,
    );

    // ── Today marker (dashed vertical, orange) ──
    final todayX = xFor(d.todayDay.toDouble());
    _dashedLine(
      canvas,
      Offset(todayX, plot.top - 2),
      Offset(todayX, plot.bottom),
      Paint()
        ..color = TbSignal.orange.border
        ..strokeWidth = 1,
    );
    _text(
      canvas,
      'TODAY',
      Offset(todayX, plot.top - 11),
      labelStyle.copyWith(color: TbSignal.orange.text),
      hCenter: true,
    );

    // ── Actual remaining line (target mode only) ──
    if (showActual && d.actualRemaining.length >= 2) {
      final pts = <Offset>[
        for (var i = 0; i < d.actualRemaining.length; i++)
          Offset(xFor(i.toDouble()), yFor(d.actualRemaining[i].toDouble())),
      ];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = TbColors.cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      final last = pts.last;
      canvas.drawCircle(last, 4, Paint()..color = TbColors.cyan);
      _text(
        canvas,
        '${d.pointsLeft} PTS LEFT',
        Offset(last.dx + 9, last.dy - 4),
        TbText.label(size: 10, weight: FontWeight.w600, color: const Color(0xFFB2EBFF), tracking: 0.3),
      );
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var dist = 0.0;
    while (dist < total) {
      final start = a + dir * dist;
      final end = a + dir * (dist + dash).clamp(0, total);
      canvas.drawLine(start, end, paint);
      dist += dash + gap;
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    bool alignRight = false,
    bool hCenter = false,
    bool vCenter = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (alignRight) dx -= tp.width;
    if (hCenter) dx -= tp.width / 2;
    var dy = at.dy;
    if (vCenter) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _BurndownPainter old) => old.showActual != showActual || old.d != d;
}
