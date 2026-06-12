// lib/features/pr_inbox/presentation/view/pr_inbox_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../data/models/pr_data.dart';
import '../providers/pr_inbox_provider.dart';
import 'widgets/pr_column.dart';

/// The PR Board — open PRs across watched repos, in columns by review state.
class PrInboxScreen extends ConsumerWidget {
  const PrInboxScreen({super.key});

  static const String routeName = 'prInbox';

  // Column order, left to right.
  static const _columns = <(PrReviewState, String)>[
    (PrReviewState.needsReview, 'Needs review'),
    (PrReviewState.changesRequested, 'Changes requested'),
    (PrReviewState.approved, 'Approved'),
    (PrReviewState.waitingOnAuthor, 'Waiting'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prs = ref.watch(prInboxProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('PR Board', style: text.headlineSmall),
              const Spacer(),
              TetherIconButton(
                icon: LucideIcons.refreshCw,
                type: TetherButtonType.ghost,
                semanticsLabel: 'Refresh',
                onPressed: () => ref.invalidate(prInboxProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: prs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _ErrorState(message: '$err', onRetry: () => ref.invalidate(prInboxProvider)),
            data: (items) => items.isEmpty ? const _EmptyState() : _Board(items: items),
          ),
        ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.items});

  final List<PrData> items;

  @override
  Widget build(BuildContext context) {
    // Each column uses Expanded internally, so it needs a bounded height; give
    // it the viewport height (minus the 8px vertical padding) and a fixed width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnHeight = constraints.maxHeight - 16;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (state, title) in PrInboxScreen._columns) ...[
                SizedBox(
                  width: 320,
                  height: columnHeight > 0 ? columnHeight : null,
                  child: PrColumn(title: title, prs: items.where((p) => p.reviewState == state).toList()),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No open PRs. Pick repos to watch in setup, or enjoy the calm.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not load PRs.\n$message', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TetherActionButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}
