import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'shared/router/app_router.dart';
import 'shared/ui/theme/app_theme.dart';
import 'shared/ui/widgets/brand_frame.dart';

class TurboBoardApp extends ConsumerWidget {
  const TurboBoardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'TurboBoard',
      debugShowCheckedModeBanner: false,
      theme: getAppTheme(brightness: Brightness.light),
      darkTheme: getAppTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      // Brand chrome (rails + grid canvas) wraps every screen.
      builder: (context, child) => BrandFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}
