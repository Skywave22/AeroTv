import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';
import 'services/deep_links.dart';
import 'screens/bootstrap_error_screen.dart';
import 'state/providers.dart';

class AeroApp extends ConsumerStatefulWidget {
  const AeroApp({this.bootError, super.key});

  final Object? bootError;

  @override
  ConsumerState<AeroApp> createState() => _AeroAppState();
}

class _AeroAppState extends ConsumerState<AeroApp> {
  final _links = DeepLinkService();
  StreamSubscription<String>? _linkSub;

  @override
  void initState() {
    super.initState();
    if (widget.bootError == null) {
      // Install links arriving from a browser or another app. The native side
      // only forwards stremio:// and aerotv://, and the service re-checks them.
      _linkSub = _links.addonLinks.listen(_installFromLink);
      unawaited(_links.start());
    }
  }

  @override
  void dispose() {
    unawaited(_linkSub?.cancel());
    unawaited(_links.dispose());
    super.dispose();
  }

  /// Routes an incoming add-on link through the normal install path so
  /// validation and the configurationRequired check still apply.
  Future<void> _installFromLink(String manifestUrl) async {
    final adapter = ref
        .read(adapterRegistryProvider)
        .forEcosystem(Ecosystem.stremio);
    if (adapter == null) return;
    final res = await adapter.install(SourceRef(
      ecosystem: Ecosystem.stremio,
      url: manifestUrl,
    ));
    if (!mounted) return;
    ref.invalidate(installedSourcesProvider);
    ref.invalidate(homeRowsProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(res.isOk
            ? 'Installed ${res.valueOrNull!.name}'
            : 'Could not install add-on: ${res.errorOrNull}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bootError = widget.bootError;
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
