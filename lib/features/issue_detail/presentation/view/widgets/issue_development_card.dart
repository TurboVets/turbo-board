// lib/features/issue_detail/presentation/view/widgets/issue_development_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../shared/ui/theme/tb_text.dart';
import '../../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../../shared/ui/widgets/open_in_github_desktop_button.dart';
import '../../../../../shared/ui/widgets/open_on_github_button.dart';
import '../../../data/models/issue_detail.dart';
import '../../providers/issue_composer_provider.dart';

/// "Development" actions: create a branch from the issue, open it in GitHub
/// Desktop once created, and open the issue on github.com.
class IssueDevelopmentCard extends HookConsumerWidget {
  const IssueDevelopmentCard({super.key, required this.issue});

  final IssueDetail issue;

  String _branchName() {
    final slug = issue.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    final short = slug.length > 40 ? slug.substring(0, 40) : slug;
    return '${issue.number}-$short';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = issue.repo.split('/');
    final owner = parts.first;
    final name = parts.length > 1 ? parts[1] : '';
    final notifier = ref.read(issueComposerProvider(owner: owner, name: name, number: issue.number).notifier);
    final createdBranch = useState<String?>(null);
    final oid = issue.repoDefaultBranchOid;
    final id = issue.id;

    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: const BoxDecoration(
              color: TbColors.surface2,
              border: Border(bottom: BorderSide(color: TbColors.border)),
            ),
            child: Text('DEVELOPMENT', style: TbText.label(size: 10, color: TbColors.muted, tracking: 1.0)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (createdBranch.value == null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.account_tree_outlined, size: 14),
                    label: const Text('Create branch…', overflow: TextOverflow.ellipsis),
                    onPressed: (id == null || oid == null)
                        ? null
                        : () async {
                            final chosen = await showDialog<String>(
                              context: context,
                              builder: (_) => _CreateBranchDialog(initialName: _branchName(), repo: issue.repo),
                            );
                            final branch = chosen?.trim();
                            if (branch == null || branch.isEmpty) return;
                            final ok = await notifier.createBranch(id, oid, branch);
                            if (ok) createdBranch.value = branch;
                          },
                  )
                else ...[
                  Text('Branch: ${createdBranch.value}', style: TbText.body(size: 12)),
                  const SizedBox(height: 8),
                  OpenInGitHubDesktopButton(
                    repo: issue.repo,
                    headRefName: createdBranch.value!,
                    number: issue.number,
                    isCrossRepository: false,
                  ),
                ],
                const SizedBox(height: 8),
                if (issue.url != null) OpenOnGitHubButton.labeled(url: issue.url!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirms branch creation, letting the user edit the name first. Returns the
/// chosen name on Create, or null on Cancel / dismiss.
class _CreateBranchDialog extends StatefulWidget {
  const _CreateBranchDialog({required this.initialName, required this.repo});

  final String initialName;
  final String repo;

  @override
  State<_CreateBranchDialog> createState() => _CreateBranchDialogState();
}

class _CreateBranchDialogState extends State<_CreateBranchDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TbColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: TbColors.border),
      ),
      title: Text('Create branch', style: TbText.label(size: 13, weight: FontWeight.w600, tracking: 0.5)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('From ${widget.repo} default branch.', style: TbText.body(size: 12, color: TbColors.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: TbText.body(size: 13, color: TbColors.text),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Branch name',
              filled: true,
              fillColor: TbColors.canvas,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: TbColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: TbColors.blue),
              ),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
