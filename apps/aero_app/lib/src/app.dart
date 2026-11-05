import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';
import 'screens/bootstrap_error_screen.dart';
import 'state/providers.dart';

class AeroApp extends ConsumerWidget {
  const AeroApp({this.bootError, super.key});

  final Object? bootError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bootError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AeroTheme.dark(),
        home: BootstrapErrorScreen(error: bootError!),
      );
    }

    final ui = ref.watch(uiSettingsProvider);
    final isTv = ref.watch(isTvProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: BrandConfig.standard.appName,
      debugShowCheckedModeBanner: false,
      theme: AeroTheme.dark(
        accent: Color(ui.accentSeed),
        tvMode: isTv,
      ),
      routerConfig: router,
      builder: (context, child) {
        // Clamp text scaling: TV users often have system font scaling that
        // would otherwise break the carefully tuned layout.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
            disableAnimations: ui.reduceMotion || mq.disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
