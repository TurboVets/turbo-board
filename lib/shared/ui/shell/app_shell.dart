// lib/shared/ui/shell/app_shell.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_ui/turbo_ui.dart';

import 'nav_rail.dart';

/// Responsive three-region shell: a left nav rail beside the routed [child].
/// The right detail/filter region arrives in later sub-projects.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// Below this width the rail collapses to icons (tablet). No phone layout.
  static const double _collapseBelow = 1100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background.primary,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed = constraints.maxWidth < _collapseBelow;
          return Row(
            children: [
              AppNavRail(collapsed: collapsed),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}
