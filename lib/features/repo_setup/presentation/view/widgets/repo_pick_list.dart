// lib/features/repo_setup/presentation/view/widgets/repo_pick_list.dart
import 'package:flutter/material.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../data/models/github_repo.dart';

class RepoPickList extends StatelessWidget {
  const RepoPickList({
    super.key,
    required this.repos,
    required this.watched,
    required this.query,
    required this.onToggle,
  });

  final List<GithubRepo> repos;
  final Set<String> watched;
  final String query;
  final void Function(GithubRepo repo) onToggle;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty ? repos : repos.where((r) => r.nameWithOwner.toLowerCase().contains(q)).toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No matching repositories.')),
      );
    }

    // Group by owner, owners alphabetical, repos by name within owner.
    final byOwner = <String, List<GithubRepo>>{};
    for (final r in filtered) {
      byOwner.putIfAbsent(r.owner, () => []).add(r);
    }
    final owners = byOwner.keys.toList()..sort();

    final colors = context.appColors;
    return ListView(
      shrinkWrap: true,
      children: [
        for (final owner in owners) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(owner, style: TextStyle(color: colors.foreground.primaryMuted, fontSize: 12)),
          ),
          for (final repo in byOwner[owner]!..sort((a, b) => a.name.compareTo(b.name)))
            TetherListItem(
              title: repo.name,
              subtitle: repo.description,
              showTrailing: true,
              trailing: TetherSwitch(
                value: watched.contains(repo.nameWithOwner),
                semanticsLabel: 'Watch ${repo.nameWithOwner}',
                onChanged: (_) => onToggle(repo),
              ),
              onTap: () => onToggle(repo),
            ),
        ],
      ],
    );
  }
}
