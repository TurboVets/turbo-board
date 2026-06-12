// lib/features/repo_setup/presentation/view/widgets/repo_pick_list.dart
import 'package:flutter/material.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/theme/tb_text.dart';
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
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('No matching repositories.', style: TbText.body(color: TbColors.muted)),
        ),
      );
    }

    // Sort alphabetically by nameWithOwner.
    final sorted = filtered.toList()..sort((a, b) => a.nameWithOwner.compareTo(b.nameWithOwner));

    return ListView.builder(
      shrinkWrap: true,
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final repo = sorted[i];
        final isWatched = watched.contains(repo.nameWithOwner);
        final isLast = i == sorted.length - 1;
        return _RepoRow(repo: repo, isWatched: isWatched, isLast: isLast, onToggle: () => onToggle(repo));
      },
    );
  }
}

/// A single repo row: "owner/name" (Akshar) + description (muted) + square toggle.
class _RepoRow extends StatefulWidget {
  const _RepoRow({required this.repo, required this.isWatched, required this.isLast, required this.onToggle});

  final GithubRepo repo;
  final bool isWatched;
  final bool isLast;
  final VoidCallback onToggle;

  @override
  State<_RepoRow> createState() => _RepoRowState();
}

class _RepoRowState extends State<_RepoRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? TbColors.surface2 : Colors.transparent,
            border: widget.isLast ? null : Border(bottom: BorderSide(color: TbColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.repo.nameWithOwner,
                      style: TbText.label(size: 13, color: TbColors.text, tracking: 0.39),
                    ),
                    if (widget.repo.description != null && widget.repo.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.repo.description!,
                        style: TbText.body(size: 11, color: TbColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 11),
              // Square toggle (38×21, rounded 4) — kept as TetherSwitch so
              // test finders (find.byType(TetherSwitch)) keep working.
              TetherSwitch(
                value: widget.isWatched,
                semanticsLabel: 'Watch ${widget.repo.nameWithOwner}',
                onChanged: (_) => widget.onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
