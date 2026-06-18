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
                    label: Text('Create branch  ${_branchName()}', overflow: TextOverflow.ellipsis),
                    onPressed: (id == null || oid == null)
                        ? null
                        : () async {
                            final ok = await notifier.createBranch(id, oid, _branchName());
                            if (ok) createdBranch.value = _branchName();
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
