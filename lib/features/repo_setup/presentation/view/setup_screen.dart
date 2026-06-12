import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:turbo_ui/turbo_ui.dart';

import '../../../../shared/ui/theme/tb_tokens.dart';
import '../../../../shared/ui/theme/tb_text.dart';
import '../../../../shared/ui/widgets/turbo_mark.dart';
import '../providers/auth_provider.dart';
import '../providers/watched_repos_provider.dart';
import 'widgets/repo_pick_list.dart';

/// First-run wizard: paste a PAT (step 1), pick watched repos (step 2).
class SetupScreen extends HookConsumerWidget {
  const SetupScreen({super.key});

  static const String routeName = 'setup';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final tokenController = useTextEditingController();
    final query = useState('');

    final onStep2 = authState is AuthAuthenticated;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Radial blue-glow background
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.9),
                  radius: 1.1,
                  colors: [Color(0x29007300), Colors.transparent],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.85),
                  radius: 0.85,
                  colors: [TbColors.blue.withValues(alpha: 0.16), Colors.transparent],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Tagline above card
          Positioned(
            top: MediaQuery.of(context).size.height * 0.13,
            left: 0,
            right: 0,
            child: Text(
              'Beside you. Behind you. After you.',
              textAlign: TextAlign.center,
              style: TbText.label(size: 12, color: TbColors.dim, tracking: 3.52),
            ),
          ),

          // Centered card — capped at 452px but shrinks to fit narrow phones.
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 452),
                child: _SetupCard(
                  step: onStep2 ? 1 : 0,
                  child: onStep2
                      ? _ReposStep(query: query)
                      : _ConnectStep(authState: authState, controller: tokenController),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 452px card with blue top accent, the Viewfinder T mark, and step bar.
class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.step, required this.child});

  final int step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TbColors.surface,
        border: Border.all(color: TbColors.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 70, offset: Offset(0, 24))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 2px blue top accent strip
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [TbColors.navy, TbColors.blueBright, TbColors.navy]),
              ),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(36, 38, 36, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Viewfinder "T" mark
                const TurboMark(size: 46),
                const SizedBox(height: 20),

                // 2-segment step bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(color: TbColors.blue, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: step >= 1 ? TbColors.blue : TbColors.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 1: connect a PAT ────────────────────────────────────────────────────

class _ConnectStep extends ConsumerWidget {
  const _ConnectStep({required this.authState, required this.controller});

  final AuthState authState;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = authState;
    final isValidating = s is AuthValidating;
    final errorText = s is AuthError ? s.message : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('TURBOBOARD', style: TbText.display(size: 21, tracking: 1.26)),
        const SizedBox(height: 7),
        Text(
          'Connect GitHub to watch every open PR across your repos in one command surface.',
          style: TbText.body(size: 14, color: TbColors.muted, height: 1.55),
        ),
        const SizedBox(height: 26),

        // Token field (keep TetherTextField for test-finder compat)
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
        Text(
          'Needs the `repo`, `read:org` and `read:project` scopes. Create one at github.com/settings/tokens.',
          style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.3),
        ),
        const SizedBox(height: 16),

        if (isValidating)
          const Center(
            child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
          )
        else
          _PrimaryButton(
            label: 'Validate & continue',
            onPressed: () => ref.read(authStateProvider.notifier).submitToken(controller.text.trim()),
          ),
      ],
    );
  }
}

// ─── Step 2: pick watched repos ───────────────────────────────────────────────

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
        Text('WATCHED REPOS', style: TbText.display(size: 21, tracking: 1.26)),
        const SizedBox(height: 7),
        Text(
          'Select the repositories you want to track in your PR board.',
          style: TbText.body(size: 14, color: TbColors.muted, height: 1.55),
        ),
        const SizedBox(height: 18),

        // Search box — filters the accessible repo list as you type.
        TetherTextField(
          hintText: 'Search repositories…',
          trailingIcon: const Icon(Icons.search, size: 20, color: TbColors.muted),
          onChanged: (value) => query.value = value,
        ),
        const SizedBox(height: 12),

        // Scrollable bordered repo list
        Container(
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            border: Border.all(color: TbColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: reposAsync.when(
            data: (repos) => RepoPickList(
              repos: repos,
              watched: watched,
              query: query.value,
              onToggle: (r) => ref.read(watchedReposProvider.notifier).toggle(r.nameWithOwner),
            ),
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('Could not load repos: $e', style: TbText.body(color: TbColors.muted)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _PrimaryButton(label: 'Open PR Board →', onPressed: watched.isEmpty ? null : () => context.go('/')),

        const SizedBox(height: 20),
        Text(
          'Change watched repos anytime from settings.',
          textAlign: TextAlign.center,
          style: TbText.label(size: 10, color: TbColors.dim, tracking: 0.3),
        ),
      ],
    );
  }
}

// ─── Shared primary button ────────────────────────────────────────────────────

/// Full-width blue Akshar button — wraps [TetherActionButton] so tests can
/// still locate it by [TetherActionButton] type + label text.
///
/// Uses [MouseRegion] to drive cyan hover color on desktop while keeping the
/// [TetherActionButton] widget in the tree (required by test finders).
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = _hovered && widget.onPressed != null ? TbColors.cyan : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TetherActionButton(
        label: widget.label,
        isExpanded: true,
        onPressed: widget.onPressed,
        backgroundColor: hoverBg,
      ),
    );
  }
}
