import 'package:flutter/material.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../data/models/cockpit_data.dart';

/// Top strip of the Lead Cockpit: sprint name + days left, a proportional status
/// bar, and six count tiles. The AI Sprint Brief / Weekly Digest now render as
/// standalone [AiNarrativeCard]s below this strip (see the cockpit screen body).
class SprintHealthStrip extends StatelessWidget {
  const SprintHealthStrip({super.key, required this.data});

  final CockpitData data;

  SprintHealth get sprint => data.sprint;

  String get _subtitle => [
    if (sprint.daysRemaining > 0) '${sprint.daysRemaining} days remaining',
    if (sprint.endLabel.isNotEmpty) sprint.endLabel,
    '${sprint.totalIssues} issues across ${sprint.repoCount} repos',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sprint.name, style: TbText.label(size: 14, weight: FontWeight.w600, tracking: 1.68)),
                const SizedBox(height: 3),
                Text(
                  _subtitle,
                  style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.6, weight: FontWeight.w400),
                ),
              ],
            ),
          ),

          // ── Status bar + tiles ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusBar(sprint: sprint),
                const SizedBox(height: 13),
                _TileRow(sprint: sprint),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Proportional status bar: done / in-progress / in-review / not-started /
/// unestimated, summing to the sprint total.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.sprint});

  final SprintHealth sprint;

  @override
  Widget build(BuildContext context) {
    final segments = <(int, Color)>[
      (3, const Color(0xFF54AE39)),
      (3, const Color(0xFF13ACFF)),
      (3, const Color(0xFFFFB000)),
      (3, const Color(0xFFBABBBF)),
      (3, const Color(0xFFFF5A1F)),
    ].where((s) => s.$1 > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        // The track background keeps the bar visible even when every segment is
        // zero (sparse board), matching the mockup's #27272A track.
        child: ColoredBox(
          color: TbColors.surface2,
          child: Row(
            children: [
              for (final (count, color) in segments)
                Expanded(
                  flex: count,
                  child: SizedBox(height: 8, child: ColoredBox(color: color)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six count tiles. Spans the full width with equal columns, matching the
/// design's `repeat(6, 1fr)` grid.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.sprint});

  final SprintHealth sprint;

  @override
  Widget build(BuildContext context) {
    final tiles = <_Tile>[
      _Tile('DONE', sprint.done, const Color(0xFF54AE39)),
      _Tile('IN PROGRESS', sprint.inProgress, const Color(0xFF13ACFF)),
      _Tile('IN REVIEW', sprint.inReview, const Color(0xFFFFB000)),
      _Tile('NOT STARTED', sprint.notStarted, const Color(0xFFBABBBF)),
      _Tile('AT RISK', sprint.atRisk, const Color(0xFFE94A5F), numColor: const Color(0xFFFBD0D3)),
      _Tile('UNESTIMATED', sprint.unestimated, const Color(0xFFFF5A1F)),
    ];

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: tiles[i])],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.count, this.dot, {this.numColor = TbColors.text});

  final String label;
  final int count;
  final Color dot;
  final Color numColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TbColors.canvas,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(width: 7, height: 7, child: ColoredBox(color: dot)),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: TbText.label(size: 20, weight: FontWeight.w700, color: numColor, tracking: 0),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.9, weight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}
