// lib/shared/ui/shell/bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../features/needs_attention/presentation/providers/needs_attention_provider.dart';
import '../theme/tb_text.dart';
import '../theme/tb_tokens.dart';
import '../widgets/tb_badge.dart';

/// Fixed bottom tab bar shown on phone-width layouts (<640px) in place of the
/// left nav rail. Mirrors the design mockup's five-tab bar: an active tab gets a
/// 2px blue top border, a blue tint, and blue icon + label.
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key});

  static const double height = 54;

  static const _tabs = <(IconData, String, String)>[
    (LucideIcons.layoutGrid, 'Board', '/'),
    (LucideIcons.circleDot, 'Attention', '/needs-attention'),
    (LucideIcons.crosshair, 'Cockpit', '/lead-cockpit'),
    (LucideIcons.columns3, 'Projects', '/projects'),
    (LucideIcons.chartNoAxesColumn, 'Report', '/sprint-report'),
    (LucideIcons.settings2, 'Settings', '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouter.maybeOf(context)?.state.matchedLocation ?? '/';
    final attentionCount = ref.watch(needsAttentionBadgeProvider);

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: TbColors.railBg,
        border: Border(top: BorderSide(color: TbColors.border)),
      ),
      child: Row(
        children: [
          for (final (icon, label, path) in _tabs)
            Expanded(
              child: _Tab(
                icon: icon,
                label: label,
                active: location == path,
                badgeCount: path == '/needs-attention' ? attentionCount : 0,
                onTap: () => context.go(path),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.active,
    required this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? TbColors.blue : TbColors.dim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? const Color(0x1F0073FF) : Colors.transparent, // rgba(0,115,255,.12)
          border: Border(top: BorderSide(color: active ? TbColors.blue : Colors.transparent, width: 2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon, with the attention badge dot overlaid when there are items.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 18, color: color),
                if (badgeCount > 0) Positioned(right: -6, top: -3, child: TbSignalDot(color: TbColors.cyan, size: 6)),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              style: TbText.label(size: 8, weight: FontWeight.w600, color: color, tracking: 0.64),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
