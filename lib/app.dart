import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'shared/router/app_router.dart';
import 'shared/ui/providers/auto_refresh_provider.dart';
import 'shared/ui/providers/text_scale_provider.dart';
import 'shared/ui/theme/app_theme.dart';
import 'shared/ui/widgets/brand_frame.dart';

/// Intent to grow the app-wide text scale (Cmd/Ctrl +).
class IncreaseFontIntent extends Intent {
  const IncreaseFontIntent();
}

/// Intent to shrink the app-wide text scale (Cmd/Ctrl -).
class DecreaseFontIntent extends Intent {
  const DecreaseFontIntent();
}

/// Intent to reset the app-wide text scale (Cmd/Ctrl 0).
class ResetFontIntent extends Intent {
  const ResetFontIntent();
}

class TurboBoardApp extends ConsumerWidget {
  const TurboBoardApp({super.key});

  // Bind both meta (macOS Cmd) and control (Windows/Linux) so the shortcut
  // works on every desktop target. `=`/`+`/numpad-add grow; `-`/numpad-subtract
  // shrink; `0` resets — mirroring browser zoom conventions.
  static const Map<ShortcutActivator, Intent> _shortcuts = {
    // macOS — Cmd
    SingleActivator(LogicalKeyboardKey.equal, meta: true): IncreaseFontIntent(),
    SingleActivator(LogicalKeyboardKey.add, meta: true): IncreaseFontIntent(),
    SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true): IncreaseFontIntent(),
    SingleActivator(LogicalKeyboardKey.minus, meta: true): DecreaseFontIntent(),
    SingleActivator(LogicalKeyboardKey.numpadSubtract, meta: true): DecreaseFontIntent(),
    SingleActivator(LogicalKeyboardKey.digit0, meta: true): ResetFontIntent(),
    SingleActivator(LogicalKeyboardKey.numpad0, meta: true): ResetFontIntent(),
    // Windows / Linux — Ctrl
    SingleActivator(LogicalKeyboardKey.equal, control: true): IncreaseFontIntent(),
    SingleActivator(LogicalKeyboardKey.add, control: true): IncreaseFontIntent(),
    SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): IncreaseFontIntent(),
    SingleActivator(LogicalKeyboardKey.minus, control: true): DecreaseFontIntent(),
    SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): DecreaseFontIntent(),
    SingleActivator(LogicalKeyboardKey.digit0, control: true): ResetFontIntent(),
    SingleActivator(LogicalKeyboardKey.numpad0, control: true): ResetFontIntent(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final scale = ref.watch(textScaleProvider);
    final notifier = ref.read(textScaleProvider.notifier);
    // Keep the app-wide periodic refresh alive; rebuilds restart its timer.
    ref.watch(autoRefreshProvider);

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: {
          IncreaseFontIntent: CallbackAction<IncreaseFontIntent>(onInvoke: (_) => notifier.increase()),
          DecreaseFontIntent: CallbackAction<DecreaseFontIntent>(onInvoke: (_) => notifier.decrease()),
          ResetFontIntent: CallbackAction<ResetFontIntent>(onInvoke: (_) => notifier.reset()),
        },
        child: MaterialApp.router(
          title: 'TurboBoard',
          debugShowCheckedModeBanner: false,
          theme: getAppTheme(brightness: Brightness.light),
          darkTheme: getAppTheme(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          routerConfig: router,
          // Brand chrome (rails + grid canvas) wraps every screen; the text
          // scaler applies app-wide.
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: BrandFrame(child: child ?? const SizedBox.shrink()),
            );
          },
        ),
      ),
    );
  }
}
