import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../ai/presentation/providers/ai_provider.dart';
import '../../../data/models/cockpit_data.dart';
import '../../providers/lead_cockpit_provider.dart';

/// Top strip of the Lead Cockpit: sprint name + days left, the AI Sprint Brief
/// toggle (live BYOK Anthropic call), a proportional status bar, and six count
/// tiles.
class SprintHealthStrip extends ConsumerWidget {
  const SprintHealthStrip({super.key, required this.data});

  final CockpitData data;

  SprintHealth get sprint => data.sprint;

  String get _subtitle => [
    if (sprint.daysRemaining > 0) '${sprint.daysRemaining} days remaining',
    if (sprint.endLabel.isNotEmpty) sprint.endLabel,
    '${sprint.totalIssues} issues across ${sprint.repoCount} repos',
  ].join(' · ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyReady = ref.watch(aiKeyReadyProvider);
    final brief = ref.watch(cockpitBriefControllerProvider);
    final controller = ref.read(cockpitBriefControllerProvider.notifier);

    final btnLabel = switch (brief) {
      AsyncLoading() => 'Analyzing…',
      AsyncData() => 'Hide brief',
      AsyncError() => 'Retry brief',
      _ => 'Sprint Brief',
    };

    void onBriefTap() {
      if (brief is AsyncLoading) return;
      if (brief is AsyncData) {
        controller.clear();
      } else {
        controller.generate(data);
      }
    }

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
            child: Row(
              children: [
                Expanded(
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
                // The AI brief is a BYOK feature; only offer it once a key is set
                // (Settings → Anthropic API key).
                if (keyReady) ...[const SizedBox(width: 14), _BriefButton(label: btnLabel, onTap: onBriefTap)],
              ],
            ),
          ),

          // ── AI brief panel ───────────────────────────────────────────────
          switch (brief) {
            AsyncLoading() => const _BriefSkeleton(),
            AsyncData(:final value) => _BriefPanel(text: value),
            AsyncError(:final error) => _BriefError(message: '$error'),
            _ => const SizedBox.shrink(),
          },

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

class _BriefButton extends StatefulWidget {
  const _BriefButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_BriefButton> createState() => _BriefButtonState();
}

class _BriefButtonState extends State<_BriefButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered ? TbColors.cyan : TbColors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xCC0A3161),
                  border: Border.all(color: TbColors.cyan),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AI',
                  style: TbText.label(size: 10, weight: FontWeight.w600, color: const Color(0xFFB2EBFF), tracking: 0.8),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TbText.label(size: 12, weight: FontWeight.w600, color: Colors.white, tracking: 0.96),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BriefError extends StatelessWidget {
  const _BriefError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TbColors.border)),
      ),
      child: Text(message, style: TbText.body(size: 13, color: const Color(0xFFFBD0D3), height: 1.55)),
    );
  }
}

class _BriefPanel extends StatelessWidget {
  const _BriefPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TbColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 2, color: TbColors.cyan),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: TbText.body(size: 13, color: const Color(0xFFDADADD), height: 1.65)),
                const SizedBox(height: 9),
                Text(
                  'Generated from the sprint board · claude-haiku · BYOK',
                  style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.8, weight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefSkeleton extends StatelessWidget {
  const _BriefSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TbColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonBar(widthFactor: 0.90),
          SizedBox(height: 9),
          _SkeletonBar(widthFactor: 0.76),
          SizedBox(height: 9),
          _SkeletonBar(widthFactor: 0.84),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(color: TbColors.surface2, borderRadius: BorderRadius.circular(4)),
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
      (sprint.done, const Color(0xFF54AE39)),
      (sprint.inProgress, const Color(0xFF13ACFF)),
      (sprint.inReview, const Color(0xFFFFB000)),
      (sprint.notStarted, const Color(0xFFBABBBF)),
      (sprint.unestimated, const Color(0xFFFF5A1F)),
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
                  child: ColoredBox(color: color),
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
