// lib/shared/ui/board/board_columns.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../theme/tb_tokens.dart';

part 'board_columns.g.dart';

/// Column sizing mode for a board, keyed by [boardId] so each board remembers
/// its own choice. `true` (default) fits every column into the viewport; `false`
/// gives columns a fixed width and scrolls horizontally. Session-scoped.
@Riverpod(keepAlive: true)
class BoardFitColumns extends _$BoardFitColumns {
  @override
  bool build(String boardId) => true;

  void toggle() => state = !state;
}

/// One column in a [BoardColumnsRow]: its [child], the relative [weight] used to
/// share space in fit mode, and the fixed [scrollWidth] used in scroll mode.
class BoardColumnSpec {
  const BoardColumnSpec({required this.child, this.weight = 236, this.scrollWidth = 236});

  final Widget child;
  final int weight;
  final double scrollWidth;
}

/// Shared board column layout. In fit mode all columns share the viewport via
/// flex ([BoardColumnSpec.weight]); in scroll mode each takes its fixed
/// [BoardColumnSpec.scrollWidth] and the row scrolls horizontally. Mode is driven
/// by [boardFitColumnsProvider] for [boardId] (toggle it with [BoardFitToggle]).
class BoardColumnsRow extends ConsumerWidget {
  const BoardColumnsRow({
    super.key,
    required this.boardId,
    required this.columns,
    this.gap = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
    this.columnVerticalInset = 0,
  });

  final String boardId;
  final List<BoardColumnSpec> columns;
  final double gap;
  final EdgeInsets padding;

  /// Subtracted from the available height to size each column (room for the
  /// scrollbar / breathing space). Columns get `maxHeight - columnVerticalInset`.
  final double columnVerticalInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(boardFitColumnsProvider(boardId));
    return LayoutBuilder(
      builder: (context, constraints) {
        final colHeight = (constraints.maxHeight - columnVerticalInset).clamp(0.0, double.infinity);

        Widget sized(Widget child) => SizedBox(height: colHeight, child: child);

        if (fit) {
          // Fit: every column shares the viewport via flex — no scroll.
          return Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(flex: columns[i].weight, child: sized(columns[i].child)),
                ],
              ],
            ),
          );
        }

        // Scroll: fixed widths, scroll horizontally through columns.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                SizedBox(width: columns[i].scrollWidth, child: sized(columns[i].child)),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Topbar toggle that flips a board between fit-to-width and horizontal-scroll.
class BoardFitToggle extends ConsumerWidget {
  const BoardFitToggle({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(boardFitColumnsProvider(boardId));
    return IconButton(
      tooltip: fit ? 'Fit all columns to width' : 'Scroll columns',
      icon: Icon(
        fit ? Icons.fit_screen_outlined : Icons.view_column_outlined,
        size: 16,
        color: fit ? TbColors.cyan : TbColors.muted,
      ),
      onPressed: () => ref.read(boardFitColumnsProvider(boardId).notifier).toggle(),
    );
  }
}
