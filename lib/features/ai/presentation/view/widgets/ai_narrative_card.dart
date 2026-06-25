// lib/features/ai/presentation/view/widgets/ai_narrative_card.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';

/// A reusable BYOK-AI narrative panel (mirrors `AI Digest Cards.dc.html`).
///
/// An idle "generate" pill expands into a staggered shimmer skeleton while
/// loading, then a data panel — prose paragraphs, or bullet rows for `- ` lines
/// — capped by a cyan gradient accent bar and a provenance caption. Errors show
/// a red message with a Retry pill and tint the card border red.
/// `state == null` means "not requested yet".
class AiNarrativeCard extends StatelessWidget {
  const AiNarrativeCard({
    super.key,
    required this.title,
    required this.idleLabel,
    required this.state,
    required this.onGenerate,
    required this.onHide,
    this.onRegenerate,
    this.caption = 'Generated from sprint board + PR state · claude-haiku · BYOK',
  });

  final String title;
  final String idleLabel;
  final AsyncValue<String>? state;
  final VoidCallback onGenerate;
  final VoidCallback onHide;

  /// When set, a "Regenerate" pill is shown alongside "Hide" in the data state —
  /// used where the result is cached and the user may want a fresh run.
  final VoidCallback? onRegenerate;
  final String caption;

  /// Body text tone from the design (#DADADD — between primary and muted).
  static const _bodyColor = Color(0xFFDADADD);

  @override
  Widget build(BuildContext context) {
    final s = state;
    final isError = s is AsyncError;
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: isError ? TbSignal.bad.border : TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: cyan star + uppercase title + action pill (hidden while loading).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, size: 11, color: TbColors.cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.4),
                  ),
                ),
                if (s is! AsyncLoading)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s is AsyncData && onRegenerate != null) ...[
                        _ActionPill(label: 'Regenerate', onTap: onRegenerate!),
                        const SizedBox(width: 8),
                      ],
                      _ActionPill(label: _actionLabel(s), onTap: _actionTap(s)),
                    ],
                  ),
              ],
            ),
          ),
          // Body, by state.
          switch (s) {
            null => const SizedBox.shrink(),
            AsyncLoading() => const _Skeleton(key: Key('ai-narrative-skeleton')),
            AsyncData(:final value) => _DataBody(text: value, caption: caption),
            AsyncError(:final error) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Text('$error', style: TbText.body(size: 13, color: TbSignal.bad.text, height: 1.6)),
            ),
          },
        ],
      ),
    );
  }

  String _actionLabel(AsyncValue<String>? s) => switch (s) {
    AsyncData() => 'Hide',
    AsyncError() => 'Retry',
    _ => idleLabel,
  };

  VoidCallback _actionTap(AsyncValue<String>? s) => switch (s) {
    AsyncData() => onHide,
    _ => onGenerate,
  };
}

/// Data panel: cyan gradient accent bar, narrative body, provenance caption.
class _DataBody extends StatelessWidget {
  const _DataBody({required this.text, required this.caption});

  final String text;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 2px cyan gradient accent bar.
        Container(
          height: 2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [TbColors.navy, TbColors.cyan, TbColors.navy]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectionArea(child: _Narrative(text: text)),
              const SizedBox(height: 10),
              Text(caption, style: TbText.label(size: 9, color: TbColors.dim, tracking: 0.7)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renders bullet lines (`- `/`• `/`* `) as cyan-square bullet rows; other lines
/// as paragraphs.
class _Narrative extends StatelessWidget {
  const _Narrative({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (_isBullet(line))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7, right: 10),
                    child: SizedBox(width: 5, height: 5, child: ColoredBox(color: TbColors.cyan)),
                  ),
                  Expanded(
                    child: Text(
                      _stripBullet(line),
                      style: TbText.body(size: 13, color: AiNarrativeCard._bodyColor, height: 1.55),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, style: TbText.body(size: 13, color: AiNarrativeCard._bodyColor, height: 1.55)),
            ),
      ],
    );
  }

  static bool _isBullet(String l) => l.startsWith('- ') || l.startsWith('• ') || l.startsWith('* ');
  static String _stripBullet(String l) => l.replaceFirst(RegExp(r'^[-*•]\s*'), '');
}

/// Three staggered shimmer bars (widths 100% / 92% / 60%).
class _Skeleton extends StatefulWidget {
  const _Skeleton({super.key});

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const widths = [1.0, 0.92, 0.6];
    const delays = [0.0, 0.15, 0.3];
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widths.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == widths.length - 1 ? 0 : 8),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widths[i],
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    // Stagger each bar's phase, oscillate opacity 0.35 → 0.8.
                    final t = (_c.value + delays[i]) % 1.0;
                    final opacity = 0.35 + 0.45 * (1 - (2 * t - 1).abs());
                    return Opacity(
                      opacity: opacity,
                      child: Container(
                        height: 11,
                        decoration: BoxDecoration(color: TbColors.surface2, borderRadius: BorderRadius.circular(3)),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cyan-outline pill (hover tint), used for Generate / Hide / Retry.
class _ActionPill extends StatefulWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_ActionPill> createState() => _ActionPillState();
}

class _ActionPillState extends State<_ActionPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x1F13ACFF) : const Color(0x00000000),
            border: Border.all(color: TbColors.cyan),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label.toUpperCase(),
            style: TbText.label(size: 10, color: TbSignal.info.text, tracking: 1.0),
          ),
        ),
      ),
    );
  }
}
