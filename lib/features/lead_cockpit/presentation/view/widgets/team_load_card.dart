import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/tb_badge.dart';
import '../../../data/models/cockpit_data.dart';
import '../../helpers/cockpit_palette.dart';

/// Per-assignee load card: avatar + handle, WIP/review/stuck counts, a 0–100
/// load gauge, and the member's current ticket titles. Overloaded members get a
/// red border + badge.
class TeamLoadCard extends StatelessWidget {
  const TeamLoadCard({super.key, required this.member});

  final TeamMemberLoad member;

  @override
  Widget build(BuildContext context) {
    final over = member.isOverloaded;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: over ? const Color(0xFFE94A5F) : TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: avatar + handle + overloaded flag
          Row(
            children: [
              TbAvatarTile(login: member.handle, size: 26),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  member.handle,
                  overflow: TextOverflow.ellipsis,
                  style: TbText.label(size: 12, weight: FontWeight.w700, tracking: 0.48),
                ),
              ),
              if (over) ...[
                const SizedBox(width: 6),
                const TbBadge(
                  'OVERLOADED',
                  TbSignal.bad,
                  small: true,
                  tooltip: 'Carrying ~2× the team median open work',
                ),
              ],
            ],
          ),
          const SizedBox(height: 11),

          // WIP number + review/stuck summary
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${member.wip}', style: TbText.label(size: 22, weight: FontWeight.w700, tracking: 0)),
              const SizedBox(width: 6),
              Text(
                'WIP',
                style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.9, weight: FontWeight.w400),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'REVIEW ${member.inReview} · STUCK ${member.stuck}',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TbText.label(size: 9, color: TbColors.muted, tracking: 0.54, weight: FontWeight.w400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Load gauge
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: TbColors.border)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (member.loadPercent.clamp(0, 100)) / 100,
                    child: ColoredBox(color: CockpitPalette.loadColor(member.loadPercent)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),

          // Member's tickets
          for (final item in member.items) _TicketRow(item: item),
        ],
      ),
    );
  }
}

/// One ticket line under a member card. Opens the GitHub issue on tap when a
/// [MemberItem.url] is present; otherwise renders as a plain (non-tappable) row.
class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.item});

  final MemberItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.url;
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 6, height: 6, child: ColoredBox(color: CockpitPalette.statusDot(item.status))),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              item.title,
              overflow: TextOverflow.ellipsis,
              style: TbText.body(size: 11, color: TbColors.muted, height: 1.2),
            ),
          ),
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
