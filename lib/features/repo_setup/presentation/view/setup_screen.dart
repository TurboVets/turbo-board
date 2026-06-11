import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../providers/auth_provider.dart';
import '../providers/watched_repos_provider.dart';
import 'widgets/auth_step_indicator.dart';
import 'widgets/repo_pick_list.dart';

/// First-run wizard: paste a PAT (step 1), pick watched repos (step 2).
class SetupScreen extends HookConsumerWidget {
  const SetupScreen({super.key});

  static const String routeName = 'setup';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final authState = ref.watch(authStateProvider);
    final tokenController = useTextEditingController();
    final query = useState('');

    final onStep2 = authState is AuthAuthenticated;

    return Scaffold(
      backgroundColor: colors.background.primary,
      body: Center(
        child: SizedBox(
          width: 452,
          child: TetherCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthStepIndicator(currentStep: onStep2 ? 1 : 0),
                const SizedBox(height: 24),
                if (!onStep2)
                  _ConnectStep(authState: authState, controller: tokenController)
                else
                  _ReposStep(query: query),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectStep extends ConsumerWidget {
  const _ConnectStep({required this.authState, required this.controller});

  final AuthState authState;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use local variable to enable smart-cast on the field type.
    final s = authState;
    final isValidating = s is AuthValidating;
    final errorText = s is AuthError ? s.message : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('TurboBoard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Paste a GitHub personal access token to watch every open PR across your repos.'),
        const SizedBox(height: 20),
        TetherTextField(
          label: 'GitHub token',
          hintText: 'ghp_…',
          obscureText: true,
          controller: controller,
          errorText: errorText,
          enabled: !isValidating,
          onSubmitted: (_) => ref.read(authStateProvider.notifier).submitToken(controller.text.trim()),
        ),
        const SizedBox(height: 8),
        const Text('Needs the `repo` and `read:org` scopes. Create one at github.com/settings/tokens.'),
        const SizedBox(height: 16),
        if (isValidating)
          const Center(
            child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
          )
        else
          TetherActionButton(
            label: 'Validate & continue',
            isExpanded: true,
            onPressed: () => ref.read(authStateProvider.notifier).submitToken(controller.text.trim()),
          ),
      ],
    );
  }
}

class _ReposStep extends ConsumerWidget {
  const _ReposStep({required this.query});

  final ValueNotifier<String> query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reposAsync = ref.watch(accessibleReposProvider);
    final watched = ref.watch(watchedReposProvider).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Watched repos', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TetherSearchField(hintText: 'Filter repositories', onChanged: (v) => query.value = v),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: reposAsync.when(
            data: (repos) => RepoPickList(
              repos: repos,
              watched: watched,
              query: query.value,
              onToggle: (r) => ref.read(watchedReposProvider.notifier).toggle(r.nameWithOwner),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load repos: $e')),
          ),
        ),
        const SizedBox(height: 16),
        TetherActionButton(
          label: 'Open PR Board →',
          isExpanded: true,
          onPressed: watched.isEmpty ? null : () => context.go('/'),
        ),
      ],
    );
  }
}
