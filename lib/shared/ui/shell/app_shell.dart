// lib/shared/ui/shell/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../theme/tb_breakpoints.dart';
import '../theme/tb_tokens.dart';
import 'bottom_nav.dart';
import 'nav_rail.dart';

/// Wraps the nav rail / bottom bar so a tap anywhere on it dismisses an open
/// detail drawer (issue/PR), which is pushed on top of the shell and now spans
/// the full content area. Translucent so the nav's own buttons still get their
/// taps; only otherwise-empty nav space falls through to here. No-op when no
/// overlay is open (base shell routes aren't poppable).
class _NavDismissArea extends StatelessWidget {
  const _NavDismissArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        while (context.canPop()) {
          context.pop();
        }
      },
      child: child,
    );
  }
}

/// Responsive app shell around the routed [child].
///
/// - Phone (<640px): content fills the width with a fixed bottom tab bar below.
/// - Tablet (640–1100px): a left nav rail collapsed to icons.
/// - Desktop (≥1100px): the full expanded left nav rail.
///
/// The outer [BrandFrame] (rails + grid canvas) already wraps this widget, so
/// the scaffold background is transparent and the canvas shows through.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final content = ColoredBox(color: TbColors.canvas, child: child);

          // Phone: single content column with a bottom tab bar.
          if (width < TbBreakpoints.mobile) {
            return Column(
              children: [
                Expanded(child: content),
                // Not const: must rebuild on each shell rebuild so the active
                // tab tracks the current route (matchedLocation).
                _NavDismissArea(child: AppBottomNav()),
              ],
            );
          }

          // Tablet/desktop: left rail beside the content (collapsed <1100px).
          final collapsed = width < TbBreakpoints.tablet;
          return Row(
            children: [
              _NavDismissArea(child: AppNavRail(collapsed: collapsed)),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}
