import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';

/// Hosts the six tabs inside the adaptive navigation shell.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    ShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    ShellDestination(
      label: 'Browse',
      icon: Icons.travel_explore_outlined,
      selectedIcon: Icons.travel_explore_rounded,
    ),
    ShellDestination(
      label: 'Search',
      icon: Icons.search_outlined,
      selectedIcon: Icons.search_rounded,
    ),
    ShellDestination(
      label: 'Library',
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library_rounded,
    ),
    ShellDestination(
      label: 'Providers',
      icon: Icons.extension_outlined,
      selectedIcon: Icons.extension_rounded,
    ),
    ShellDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(isTvProvider);
    final ui = ref.watch(uiSettingsProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);

    return AppShell(
      brandName: BrandConfig.standard.appName,
      destinations: _destinations,
      selectedIndex: navigationShell.currentIndex,
      formFactor: formFactor,
      overscanPercent: ui.tvOverscanPercent,
      onSelect: (i) => navigationShell.goBranch(
        i,
        // Tapping the active tab returns to that branch's root.
        initialLocation: i == navigationShell.currentIndex,
      ),
      child: navigationShell,
    );
  }
}
