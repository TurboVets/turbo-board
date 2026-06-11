import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/pr_inbox/presentation/view/pr_inbox_screen.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', name: PrInboxScreen.routeName, builder: (context, state) => const PrInboxScreen())],
  );
}
