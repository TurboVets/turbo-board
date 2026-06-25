import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/cockpit_data.dart';

/// Sprint Flow · Daily Activity — a burnup chart (cumulative done vs opened)
/// over a card with a horizontal strip of per-weekday tiles. Tapping a day
/// opens a popup listing the tickets closed/opened that day.
///
/// Sourced from each board item's `createdAt` / `closedAt` (see [SprintFlow]),
/// so it shows throughput and inflow — not board-column moves.
class SprintFlowSection extends StatelessWidget {
  const SprintFlowSection({super.key, required this.flow, DateTime? today}) : _today = today;

  final SprintFlow flow;
  final DateTime? _today;

  static const Color _done = Color(0xFF54AE39);
  static const Color _opened = Color(0xFF6E7681);

  @override
  Widget build(BuildContext context) {
    final now = _today ?? DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header + legend ──────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                'SPRINT FLOW · DAILY ACTIVITY',
                style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4),
              ),
            ),
            const _LegendDot(color: _done, label: 'DONE'),
            const SizedBox(width: 14),
            const _LegendDot(color: _opened, label: 'OPENED'),
          ],
        ),
        const SizedBox(height: 10),
        // ── Card: chart + tile strip ─────────────────────────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            color: TbColors.surface,
            border: Border.all(color: TbColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (flow.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No activity recorded this sprint yet.',
                    textAlign: TextAlign.center,
                    style: TbText.body(size: 13, color: TbColors.dim),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                  child: SizedBox(
                    height: 200,
                    child: _Burnup(flow: flow, todayKey: todayKey),
                  ),
                ),
                _StripHeader(),
                _TileStrip(flow: flow, todayKey: todayKey),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TbText.label(size: 9, color: TbColors.muted, tracking: 1.0)),
      ],
    );
  }
}

class _StripHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        color: TbColors.canvas,
        border: Border(
          top: BorderSide(color: TbColors.border),
          bottom: BorderSide(color: TbColors.border),
        ),
      ),
      child: Row(
        children: [
          Text('DAILY ACTIVITY', style: TbText.label(size: 9, color: TbColors.dim, tracking: 1.2)),
          const SizedBox(width: 10),
          Text('TAP A DAY FOR DETAIL', style: TbText.label(size: 9, color: TbColors.borderStrong, tracking: 0.8)),
        ],
      ),
    );
  }
}

/// Horizontally scrollable row of one square tile per sprint weekday.
class _TileStrip extends StatelessWidget {
  const _TileStrip({required this.flow, required this.todayKey});

  final SprintFlow flow;
  final DateTime todayKey;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          for (final day in flow.days) ...[
            _DayTile(day: day, todayKey: todayKey),
            if (day != flow.days.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.todayKey});

  final FlowDay day;
  final DateTime todayKey;

  static const List<String> _dow = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  bool get _isToday => day.date == todayKey;
  bool get _isFuture => day.date.isAfter(todayKey);

  @override
  Widget build(BuildContext context) {
    final dowColor = _isToday
        ? TbColors.cyan
        : _isFuture
        ? TbColors.borderStrong
        : TbColors.muted;
    final dnumColor = _isToday
        ? TbColors.cyan
        : _isFuture
        ? TbColors.borderStrong
        : TbColors.text;
    final doneColor = day.done > 0 ? const Color(0xFF54AE39) : TbColors.borderStrong;
    final openedColor = day.opened > 0 ? TbColors.muted : TbColors.borderStrong;

    final tile = Container(
      width: 92,
      height: 86,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: _isToday ? TbColors.surface2 : TbColors.canvas,
        border: Border.all(color: _isToday ? TbColors.cyan : TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_dow[day.date.weekday - 1], style: TbText.label(size: 9, color: dowColor, tracking: 1.2)),
              const SizedBox(width: 5),
              Text(
                '${day.date.day}',
                style: TbText.label(size: 14, weight: FontWeight.w700, color: dnumColor, tracking: 0.2),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _Stat(symbol: '✓', value: day.done, color: doneColor),
              const SizedBox(width: 11),
              _Stat(symbol: '+', value: day.opened, color: openedColor),
            ],
          ),
        ],
      ),
    );

    if (_isFuture) return Opacity(opacity: 0.45, child: tile);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => _showDayDetail(context, day), child: tile),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.symbol, required this.value, required this.color});

  final String symbol;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          symbol,
          style: TbText.label(size: 11, weight: FontWeight.w700, color: color, tracking: 0),
        ),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: TbText.label(size: 13, weight: FontWeight.w700, color: color, tracking: 0),
        ),
      ],
    );
  }
}

Future<void> _showDayDetail(BuildContext context, FlowDay day) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _DayDetailDialog(day: day),
  );
}

class _DayDetailDialog extends StatelessWidget {
  const _DayDetailDialog({required this.day});

  final FlowDay day;

  static const List<String> _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  static const List<String> _dowLong = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${_dowLong[day.date.weekday - 1]} ${_months[day.date.month - 1]} ${day.date.day}';

    return Dialog(
      backgroundColor: TbColors.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: TbColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 2, color: TbColors.cyan),
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          style: TbText.label(size: 14, weight: FontWeight.w600, color: TbColors.text, tracking: 1.0),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${day.done} DONE · ${day.opened} OPENED',
                          style: TbText.label(size: 9, color: TbColors.dim, tracking: 1.0),
                        ),
                      ],
                    ),
                  ),
                  _CloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (day.doneTickets.isNotEmpty) ...[
                      _GroupLabel('DONE', const Color(0xFF54AE39)),
                      for (final t in day.doneTickets)
                        _TicketRow(ticket: t, symbol: '✓', symbolColor: const Color(0xFF54AE39)),
                    ],
                    if (day.openedTickets.isNotEmpty) ...[
                      _GroupLabel('OPENED', TbColors.dim),
                      for (final t in day.openedTickets) _TicketRow(ticket: t, symbol: '+', symbolColor: TbColors.dim),
                    ],
                    if (day.doneTickets.isEmpty && day.openedTickets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'No ticket detail for this day.',
                          textAlign: TextAlign.center,
                          style: TbText.body(size: 13, color: TbColors.dim),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            border: Border.all(color: TbColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.close, size: 14, color: TbColors.muted),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 13, 4, 6),
      child: Text(text, style: TbText.label(size: 9, color: color, tracking: 1.2)),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.symbol, required this.symbolColor});

  final FlowTicket ticket;
  final String symbol;
  final Color symbolColor;

  @override
  Widget build(BuildContext context) {
    final url = ticket.url;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              symbol,
              textAlign: TextAlign.center,
              style: TbText.label(size: 13, weight: FontWeight.w700, color: symbolColor, tracking: 0),
            ),
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 40,
            child: Text(
              ticket.number,
              style: TbText.label(size: 11, weight: FontWeight.w600, color: TbColors.dim, tracking: 0.2),
            ),
          ),
          Expanded(
            child: Text(ticket.title, style: TbText.body(size: 13, color: const Color(0xFFDADADD))),
          ),
          if (ticket.assignee.isNotEmpty) ...[
            const SizedBox(width: 11),
            Tooltip(
              message: ticket.assignee,
              child: TbAvatarTile(login: ticket.assignee, size: 18),
            ),
          ],
          const SizedBox(width: 10),
          Text(ticket.repo, style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.4, upper: false)),
        ],
      ),
    );

    if (url == null || url.isEmpty) return row;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: row,
      ),
    );
  }
}

/// Cumulative burnup: a filled "done" line and a dashed "opened/scope" line
/// across the sprint's weekdays, with a vertical marker on today. Lines are
/// drawn only through today; future days appear as dimmed x-axis labels.
class _Burnup extends StatelessWidget {
  const _Burnup({required this.flow, required this.todayKey});

  final SprintFlow flow;
  final DateTime todayKey;

  @override
  Widget build(BuildContext context) {
    final days = flow.days;
    // Cumulative series.
    final cumDone = <int>[];
    final cumOpened = <int>[];
    var dAcc = 0;
    var oAcc = 0;
    for (final day in days) {
      dAcc += day.done;
      oAcc += day.opened;
      cumDone.add(dAcc);
      cumOpened.add(oAcc);
    }

    var todayIdx = -1;
    for (var i = 0; i < days.length; i++) {
      if (!days[i].date.isAfter(todayKey)) todayIdx = i;
    }
    if (todayIdx < 0) todayIdx = days.length - 1;

    final peak = [for (final v in cumDone) v, for (final v in cumOpened) v].fold<int>(0, (m, v) => v > m ? v : m);
    final step = _chooseStep(peak);
    final maxVal = peak <= 0 ? step : ((peak + step - 1) ~/ step) * step;

    return CustomPaint(
      size: Size.infinite,
      painter: _BurnupPainter(
        days: days,
        cumDone: cumDone,
        cumOpened: cumOpened,
        todayIdx: todayIdx,
        maxVal: maxVal,
        step: step,
      ),
    );
  }

  static int _chooseStep(int peak) {
    for (final s in [2, 5, 10, 20, 25, 50, 100]) {
      if (peak / s <= 5) return s;
    }
    return 200;
  }
}

class _BurnupPainter extends CustomPainter {
  _BurnupPainter({
    required this.days,
    required this.cumDone,
    required this.cumOpened,
    required this.todayIdx,
    required this.maxVal,
    required this.step,
  });

  final List<FlowDay> days;
  final List<int> cumDone;
  final List<int> cumOpened;
  final int todayIdx;
  final int maxVal;
  final int step;

  static const _done = Color(0xFF54AE39);
  static const _opened = Color(0xFF6E7681);
  static const _gridBase = Color(0xFF303036);
  static const _grid = Color(0xFF262B33);
  static const _axisText = Color(0xFF5B636E);
  static const _today = Color(0xFF13ACFF);
  static const List<String> _dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const top = 14.0;
    final right = size.width;
    final bottom = size.height - 24;
    final plotW = right - left;
    final plotH = bottom - top;
    if (plotW <= 0 || plotH <= 0 || days.isEmpty) return;

    double xAt(int i) => days.length == 1 ? left + plotW / 2 : left + plotW * (i / (days.length - 1));
    double yAt(num v) => bottom - (v / maxVal) * plotH;

    // ── Gridlines + y labels ────────────────────────────────────────────
    for (var v = 0; v <= maxVal; v += step) {
      final y = yAt(v);
      final paint = Paint()
        ..color = v == 0 ? _gridBase : _grid
        ..strokeWidth = 1;
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
      _text(canvas, '$v', Offset(left - 6, y), _axisText, 10, align: TextAlign.right, anchorRight: true, vCenter: true);
    }

    // ── Today marker ────────────────────────────────────────────────────
    final tx = xAt(todayIdx);
    _dashedLine(canvas, Offset(tx, top), Offset(tx, bottom), _today.withValues(alpha: 0.85));
    _text(canvas, 'TODAY', Offset(tx, top - 12), _today, 9, align: TextAlign.center, center: true, tracking: 1.4);

    // ── Done area + lines (through today only) ──────────────────────────
    final lastIdx = todayIdx.clamp(0, days.length - 1);
    final donePts = [for (var i = 0; i <= lastIdx; i++) Offset(xAt(i), yAt(cumDone[i]))];
    final openedPts = [for (var i = 0; i <= lastIdx; i++) Offset(xAt(i), yAt(cumOpened[i]))];

    if (donePts.length >= 2) {
      final area = Path()..moveTo(donePts.first.dx, donePts.first.dy);
      for (final p in donePts.skip(1)) {
        area.lineTo(p.dx, p.dy);
      }
      area
        ..lineTo(donePts.last.dx, bottom)
        ..lineTo(donePts.first.dx, bottom)
        ..close();
      canvas.drawPath(area, Paint()..color = _done.withValues(alpha: 0.09));
    }

    _polyline(canvas, openedPts, _opened, dashed: true);
    _polyline(canvas, donePts, _done);

    for (final p in openedPts) {
      canvas.drawCircle(p, 2.6, Paint()..color = _opened);
    }
    for (var i = 0; i < donePts.length; i++) {
      final isToday = i == lastIdx;
      canvas.drawCircle(donePts[i], isToday ? 4.4 : 3.4, Paint()..color = _done);
      if (isToday) {
        canvas.drawCircle(
          donePts[i],
          4.4,
          Paint()
            ..color = _today
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // ── X labels ────────────────────────────────────────────────────────
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final isToday = i == todayIdx;
      final isFuture = i > todayIdx;
      final color = isToday ? _today : (isFuture ? const Color(0xFF45454C) : const Color(0xFF6E6E76));
      _text(
        canvas,
        '${_dow[d.date.weekday - 1]} ${d.date.day}',
        Offset(xAt(i), bottom + 6),
        color,
        10,
        align: TextAlign.center,
        center: true,
      );
    }
  }

  void _polyline(Canvas canvas, List<Offset> pts, Color color, {bool dashed = false}) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 1.5 : 2
      ..strokeJoin = StrokeJoin.round;
    if (!dashed) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
      return;
    }
    for (var i = 0; i < pts.length - 1; i++) {
      _dashedLine(canvas, pts[i], pts[i + 1], color, width: 1.5);
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Color color, {double width = 1}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    const dash = 5.0;
    const gap = 4.0;
    var dist = 0.0;
    while (dist < total) {
      final segEnd = (dist + dash).clamp(0.0, total);
      canvas.drawLine(a + dir * dist, a + dir * segEnd, paint);
      dist += dash + gap;
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    Color color,
    double size, {
    TextAlign align = TextAlign.left,
    bool center = false,
    bool anchorRight = false,
    bool vCenter = false,
    double tracking = 0.4,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TbText.label(size: size, color: color, tracking: tracking, weight: FontWeight.w400, upper: false),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (center) dx -= tp.width / 2;
    if (anchorRight) dx -= tp.width;
    final dy = vCenter ? at.dy - tp.height / 2 : at.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_BurnupPainter old) =>
      old.days != days || old.todayIdx != todayIdx || old.maxVal != maxVal || old.step != step;
}
