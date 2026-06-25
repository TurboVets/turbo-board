import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/cockpit_data.dart';
import '../../helpers/cockpit_palette.dart';

/// How the load gauge is scaled: against a fixed per-person point capacity, or
/// relative to the busiest member on the board.
enum GaugeMode { capacity, relative }

/// Per-assignee load card. Four stacked sections: header (avatar + handle +
/// state/priority badges), stats (WIP + chip row), points-based load gauge, and
/// the member's top ticket lines. Mirrors the `TurboBoard.dc.html` cockpit card.
class TeamLoadCard extends StatelessWidget {
  const TeamLoadCard({super.key, required this.member, required this.gaugeMode, required this.maxPoints});

  final TeamMemberLoad member;
  final GaugeMode gaugeMode;

  /// Highest point total across the team — the 100% mark in [GaugeMode.relative].
  final int maxPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        // Overload red border hidden for now — see OVERLOADED badge note below.
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(member: member),
          _Stats(member: member),
          _Gauge(member: member, gaugeMode: gaugeMode, maxPoints: maxPoints),
          if (member.items.isNotEmpty) _TicketList(items: member.items),
        ],
      ),
    );
  }
}

/// ① Avatar + handle, with P0/P1 carry and over/under-load state badges.
class _Header extends StatelessWidget {
  const _Header({required this.member});

  final TeamMemberLoad member;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (member.highPriority > 0)
        TbBadge(
          '${member.highPriority}×P0/P1',
          TbSignal.bad,
          small: true,
          tooltip: 'Carrying ${member.highPriority} high-priority (P0/P1) item(s)',
        ),
      // OVERLOADED badge hidden for now — thresholds (points >= 35 || wip >= 5)
      // aren't calibrated for this team's velocity. Re-enable once configurable.
      // if (member.isOverloaded)
      //   const TbBadge(
      //     'OVERLOADED',
      //     TbSignal.bad,
      //     small: true,
      //     tooltip: 'Heavy load — needs work pulled off their plate',
      //   ),
      if (member.isAvailable)
        const TbBadge('AVAILABLE', TbSignal.gray, small: true, tooltip: 'Has headroom to take a handoff'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TbColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TbAvatarTile(login: member.handle, size: 28),
          const SizedBox(width: 8),
          // Handle + badges stack; badges wrap to a second line on narrow cards
          // rather than overflowing the row.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '@${member.handle}',
                    overflow: TextOverflow.ellipsis,
                    style: TbText.label(size: 12, weight: FontWeight.w600, tracking: 0.48),
                  ),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: badges),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ② Big WIP number + a wrap of count chips (review / done / points / stuck / unsized).
class _Stats extends StatelessWidget {
  const _Stats({required this.member});

  final TeamMemberLoad member;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${member.wip}', style: TbText.label(size: 24, weight: FontWeight.w700, tracking: 0)),
              const SizedBox(width: 5),
              Text(
                'WIP',
                style: TbText.label(size: 9, color: TbColors.dim, tracking: 1.0, weight: FontWeight.w400),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TbBadge('REVIEW ${member.inReview}', TbSignal.gray, small: true, tooltip: 'Items currently in review'),
              TbBadge('DONE ${member.done}', TbSignal.ok, small: true, tooltip: 'Completed items in this sprint'),
              TbBadge('${member.points}PTS', TbSignal.info, small: true, tooltip: 'Sum of story points across all open items'),
              if (member.stuck > 0) TbBadge('STUCK ${member.stuck}', TbSignal.bad, small: true, tooltip: 'Items that are currently blocked'),
              if (member.unestimated > 0)
                TbBadge(
                  '${member.unestimated} UNSIZED',
                  TbSignal.orange,
                  small: true,
                  tooltip: 'Open items with no estimate',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ③ Points-based load bar + percent / scale-context readout.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.member, required this.gaugeMode, required this.maxPoints});

  final TeamMemberLoad member;
  final GaugeMode gaugeMode;
  final int maxPoints;

  @override
  Widget build(BuildContext context) {
    final raw = switch (gaugeMode) {
      GaugeMode.capacity => member.points / CockpitPalette.pointsCapacity,
      GaugeMode.relative => maxPoints == 0 ? 0.0 : member.points / maxPoints,
    };
    final pct = (raw * 100).round().clamp(0, 100);
    final color = CockpitPalette.gaugeColor(pct);
    final ctx = switch (gaugeMode) {
      GaugeMode.capacity => '${member.points} / ${CockpitPalette.pointsCapacity} PTS',
      GaugeMode.relative => '${member.points} / $maxPoints MAX',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: TbColors.surface2)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct / 100,
                    child: ColoredBox(color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$pct%',
                style: TbText.label(size: 9, color: color, tracking: 0.6, weight: FontWeight.w400),
              ),
              Text(
                ctx,
                style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.6, weight: FontWeight.w400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ④ Up to three ticket lines; each opens its GitHub issue on tap when a URL is
/// present, and flags stuck items with a red dot + age tag.
class _TicketList extends StatelessWidget {
  const _TicketList({required this.items});

  final List<MemberItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TbColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final item in items) _TicketRow(item: item)],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.item});

  final MemberItem item;

  @override
  Widget build(BuildContext context) {
    final dotColor = item.stuck ? const Color(0xFFE94A5F) : CockpitPalette.statusDot(item.status);
    final url = item.url;

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TbColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 6, height: 6, child: ColoredBox(color: dotColor)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              item.title,
              overflow: TextOverflow.ellipsis,
              style: TbText.body(size: 11, color: TbColors.muted, height: 1.3),
            ),
          ),
          if (item.hasSubIssues) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: TbColors.surface2,
                border: Border.all(color: TbColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${item.subDone ?? 0}/${item.subTotal}',
                style: TbText.label(size: 9, color: TbColors.muted, tracking: 0.4, weight: FontWeight.w600),
              ),
            ),
          ],
          if (item.stuck) ...[
            const SizedBox(width: 6),
            Text(
              '${item.ageDays}D',
              style: TbText.label(size: 9, color: const Color(0xFFFF5A1F), tracking: 0.4, weight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );

    if (url == null) return row;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Tooltip(message: 'Open issue on GitHub', child: row),
      ),
    );
  }
}
