import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turbo_ui/turbo_ui.dart';

import '../../data/models/pr_data.dart';
import '../providers/pr_inbox_provider.dart';

/// PR Inbox — all open PRs across watched repos.
///
/// Adaptive shell: navigation rail on desktop/tablet/web widths.
/// This app is not designed for phone-sized screens.
class PrInboxScreen extends HookConsumerWidget {
  const PrInboxScreen({super.key});

  static const String routeName = 'prInbox';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedNavIndex = useState(0);
    final prs = ref.watch(prInboxProvider);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedNavIndex.value,
            onDestinationSelected: (i) => selectedNavIndex.value = i,
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(LucideIcons.gitPullRequest),
                label: Text('PRs'),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(prInboxProvider),
              child: prs.when(
                data: (items) => _PrList(items: items),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Could not load PRs: $err')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrList extends StatelessWidget {
  const _PrList({required this.items});

  final List<PrData> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No open PRs. Nice work.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _PrCard(pr: items[index]),
    );
  }
}

class _PrCard extends StatelessWidget {
  const _PrCard({required this.pr});

  final PrData pr;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              pr.isDraft ? LucideIcons.gitPullRequestDraft : LucideIcons.gitPullRequest,
              color: colors.foreground.link,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pr.title, style: textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    '${pr.slug} · ${pr.author} · updated ${timeago.format(pr.updatedAt)}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusChip(label: pr.reviewState.name),
            const SizedBox(width: 8),
            _CiIcon(state: pr.ciState),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: colors.foreground.link),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _CiIcon extends StatelessWidget {
  const _CiIcon({required this.state});

  final PrCiState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      PrCiState.passing => (LucideIcons.circleCheck, Colors.green),
      PrCiState.pending => (LucideIcons.circleDashed, Colors.amber),
      PrCiState.failing => (LucideIcons.circleX, Colors.red),
    };

    return Icon(icon, size: 18, color: color);
  }
}
