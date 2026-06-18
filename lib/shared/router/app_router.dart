import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/lead_cockpit/presentation/view/lead_cockpit_screen.dart';
import '../../features/projects_board/presentation/view/projects_board_screen.dart';
import '../../features/needs_attention/presentation/view/needs_attention_screen.dart';
import '../../features/pr_detail/presentation/view/pr_detail_screen.dart';
import '../../features/pr_inbox/presentation/view/pr_inbox_screen.dart';
import '../../features/repo_setup/presentation/providers/auth_provider.dart';
import '../../features/settings/presentation/view/settings_screen.dart';
import '../../features/sprint_report/presentation/view/sprint_report_screen.dart';
import '../../features/repo_setup/presentation/view/setup_screen.dart';
import '../ui/shell/app_shell.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Re-run redirects whenever auth state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final onSetup = state.matchedLocation == '/setup';
      return switch (auth) {
        AuthValidating() => null, // don't bounce mid-validation
        AuthAuthenticated() => null, // allow both '/' and '/setup'; user exits step 2 explicitly
        _ => onSetup ? null : '/setup', // unauthenticated / error -> force to setup
      };
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: PrInboxScreen.routeName,
            builder: (context, state) => _opaque(const PrInboxScreen()),
          ),
          GoRoute(
            path: '/needs-attention',
            name: NeedsAttentionScreen.routeName,
            builder: (context, state) => _opaque(const NeedsAttentionScreen()),
          ),
          GoRoute(
            path: '/lead-cockpit',
            name: LeadCockpitScreen.routeName,
            builder: (context, state) => _opaque(const LeadCockpitScreen()),
          ),
          GoRoute(
            path: '/projects',
            name: ProjectsBoardScreen.routeName,
            builder: (context, state) => _opaque(const ProjectsBoardScreen()),
          ),
          GoRoute(
            path: '/sprint-report',
            name: SprintReportScreen.routeName,
            builder: (context, state) => _opaque(const SprintReportScreen()),
          ),
          GoRoute(
            path: '/settings',
            name: SettingsScreen.routeName,
            builder: (context, state) => _opaque(const SettingsScreen()),
          ),
          GoRoute(
            path: '/pr/:owner/:repo/:number',
            name: PrDetailScreen.routeName,
            // Transparent overlay so the board stays painted behind the drawer.
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              opaque: false,
              barrierDismissible: false,
              transitionDuration: const Duration(milliseconds: 220),
              child: PrDetailScreen(
                owner: state.pathParameters['owner']!,
                repo: state.pathParameters['repo']!,
                number: int.tryParse(state.pathParameters['number'] ?? '') ?? 0,
              ),
              transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
            ),
          ),
        ],
      ),
      GoRoute(path: '/setup', name: SetupScreen.routeName, builder: (context, state) => const SetupScreen()),
    ],
  );
}

/// Wraps a shell content screen in an opaque [colorScheme.surface] background so
/// the screen beneath it never bleeds through during route transitions (e.g.
/// when the PR detail overlay pops). PR detail itself is intentionally left
/// transparent so it can float over the board as a drawer.
Widget _opaque(Widget child) => _ShellSurface(child: child);

class _ShellSurface extends StatelessWidget {
  const _ShellSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: Theme.of(context).colorScheme.surface, child: child);
}
