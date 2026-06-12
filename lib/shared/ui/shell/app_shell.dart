// lib/shared/ui/shell/app_shell.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../theme/tb_tokens.dart';
import 'nav_rail.dart';

/// Responsive two-region shell: a left nav rail beside the routed [child].
/// The rail collapses to icon-only at tablet widths (<1100 px).
/// The outer [BrandFrame] (rails + grid canvas) already wraps this widget, so
/// the scaffold background is transparent and the canvas shows through.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// Below this width the rail collapses to icons (tablet). No phone layout.
  static const double _collapseBelow = 1100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed = constraints.maxWidth < _collapseBelow;
          return Row(
            children: [
              AppNavRail(collapsed: collapsed),
              Expanded(
                child: ColoredBox(color: TbColors.canvas, child: child),
              ),
            ],
          );
        },
      ),
    );
  }
}
