import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/pr_inbox/presentation/view/pr_inbox_screen.dart';
import '../../features/repo_setup/presentation/providers/auth_provider.dart';
import '../../features/repo_setup/presentation/view/setup_screen.dart';

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
      GoRoute(path: '/', name: PrInboxScreen.routeName, builder: (context, state) => const PrInboxScreen()),
      GoRoute(path: '/setup', name: SetupScreen.routeName, builder: (context, state) => const SetupScreen()),
    ],
  );
}
