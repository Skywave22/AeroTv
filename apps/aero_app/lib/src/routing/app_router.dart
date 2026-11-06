import 'package:aero_core/aero_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/details_screen.dart';
import '../screens/extensions_screen.dart';
import '../screens/browse_screen.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/logs_screen.dart';
import '../screens/source_diagnostics_screen.dart';
import '../screens/provider_home_screen.dart';
import '../screens/providers_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/shell_screen.dart';
import '../state/providers.dart';

/// Route names used across the app.
class Routes {
  static const home = '/';
  static const browse = '/browse';
  static const search = '/search';
  static const library = '/library';
  static const providers = '/providers';
  static const settings = '/settings';
  static const extensions = '/extensions';
  static const logs = '/logs';
  static const diagnostics = '/diagnostics';
  static const providerHome = '/provider';
  static const details = '/details';
}

final _rootKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.browse,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: BrowseScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.search,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SearchScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.library,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: LibraryScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.providers,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProvidersScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SettingsScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'extensions',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => ExtensionsScreen(
                      initialEcosystem:
                          Ecosystem.tryFromId(state.uri.queryParameters['eco']),
                    ),
                  ),
                  GoRoute(
                    path: 'logs',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const LogsScreen(),
                  ),
                  GoRoute(
                    path: 'diagnostics',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) {
                      final extra = state.extra;
                      return SourceDiagnosticsScreen(
                        source: extra is InstalledSource ? extra : null,
                        sourceId: state.uri.queryParameters['id'],
                        ecosystemId: state.uri.queryParameters['eco'],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.providerHome,
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final extra = state.extra;
          return ProviderHomeScreen(
            source: extra is InstalledSource ? extra : null,
            sourceId: state.uri.queryParameters['id'],
            ecosystemId: state.uri.queryParameters['eco'],
          );
        },
      ),
      GoRoute(
        path: Routes.details,
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is DetailsArgs) return DetailsScreen(args: extra);
          // Deep-link fallback: /details?id=tt123&type=movie
          final id = state.uri.queryParameters['id'] ?? '';
          final type = MediaType.fromWire(state.uri.queryParameters['type']);
          return DetailsScreen(
            args: DetailsArgs(
              ref: MediaRef(id: id, type: type, imdbId: extractImdbId(id)),
            ),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

/// Convenience navigation helpers.
extension AeroNavigation on BuildContext {
  void openDetails(MediaRef ref, {String? sourceId, Ecosystem? ecosystem}) {
    push(
      Routes.details,
      extra: DetailsArgs(
        ref: ref,
        preferredSourceId: sourceId,
        preferredEcosystem: ecosystem,
      ),
    );
  }

  void openProviderHome(InstalledSource source) {
    push(Routes.providerHome, extra: source);
  }

  void openDiagnostics(InstalledSource source) {
    push('${Routes.settings}/diagnostics', extra: source);
  }

  void openExtensions({Ecosystem? ecosystem}) {
    final q = ecosystem == null ? '' : '?eco=${ecosystem.id}';
    push('${Routes.settings}/extensions$q');
  }
}
