import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';
import '../widgets/hero_from_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _focusMemory = RowFocusMemory();

  @override
  void dispose() {
    _focusMemory.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTv = ref.watch(isTvProvider);
    final ui = ref.watch(uiSettingsProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);
    final sourcesAsync = ref.watch(installedSourcesProvider);
    final rowsAsync = ref.watch(homeRowsProvider);
    final continueAsync = ref.watch(continueWatchingProvider);
    final tmdbConfigured =
        ref.watch(settingsRepoProvider).tmdbApiKey.trim().isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeRowsProvider);
          ref.invalidate(installedSourcesProvider);
          await ref.read(homeRowsProvider.future);
        },
        child: sourcesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load your add-ons',
            message: '$e',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(installedSourcesProvider),
          ),
          data: (sources) {
            // Neutral posture: no bundled sources, so the empty state is the
            // first thing a new user sees.
            if (sources.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                  EmptyState(
                    icon: Icons.extension_outlined,
                    title: 'Welcome to Aero TV',
                    message:
                        'Aero TV is a player and plugin host. It ships with no '
                        'content and no sources.\n\nAdd your own add-ons, or '
                        'set a TMDB key to fill Home with trending and popular '
                        'titles while your scrapers supply the streams.',
                    actionLabel: 'Add an add-on',
                    onAction: () => context.openExtensions(),
                    secondaryLabel: tmdbConfigured ? 'Learn more' : 'Set TMDB key',
                    onSecondary: () => tmdbConfigured
                        ? _showAboutSources(context)
                        : context.go(Routes.settings),
                  ),
                ],
              );
            }

            return rowsAsync.when(
              loading: () => _LoadingHome(formFactor: formFactor),
              error: (e, _) => EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Nothing loaded',
                message:
                    'Your enabled add-ons did not return any catalogs.\n\n$e',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(homeRowsProvider),
                secondaryLabel: 'Manage add-ons',
                onSecondary: () => context.openExtensions(),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return ListView(
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
                      EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'Nothing on Home yet',
                        message: tmdbConfigured
                            ? 'No trending rows came back from TMDB, and no '
                                'add-on returned a catalog. Check that your '
                                'add-ons are enabled and reachable.\n\n'
                                'SkyStream and Vega providers are browsed from '
                                'the Browse tab, not shown here.'
                            : 'Home is filled by add-on catalogs and TMDB. '
                                'Set a free TMDB key for trending and popular '
                                'rows, or add an add-on.\n\n'
                                'SkyStream and Vega providers are browsed from '
                                'the Browse tab, not shown here.',
                        actionLabel:
                            tmdbConfigured ? 'Manage add-ons' : 'Set TMDB key',
                        onAction: () => tmdbConfigured
                            ? context.openExtensions()
                            : context.go(Routes.settings),
                        secondaryLabel: 'Retry',
                        onSecondary: () => ref.invalidate(homeRowsProvider),
                      ),
                    ],
                  );
                }

                final continueItems = continueAsync.valueOrNull ?? const [];
                final heroItems = pickHeroItems(rows.first.items);

                return CustomScrollView(
                  slivers: [
                    if (heroItems.isNotEmpty)
                      SliverToBoxAdapter(
                        child: HeroBanner(
                          items: heroItems,
                          formFactor: formFactor,
                          reduceMotion: ui.reduceMotion,
                          rotationSeconds: ui.heroRotationSeconds,
                          onPlay: (item) => context.openDetails(item.ref),
                          onMoreInfo: (item) => context.openDetails(item.ref),
                        ),
                      ),
                    if (continueItems.isNotEmpty)
                      SliverToBoxAdapter(
                        child: MediaRow(
                          title: 'Continue Watching',
                          rowKey: 'continue',
                          items: continueItems.map((e) => e.item).toList(),
                          formFactor: formFactor,
                          focusMemory: _focusMemory,
                          reduceMotion: ui.reduceMotion,
                          progressFor: (item) {
                            final e = continueItems.firstWhere(
                              (x) => x.item.ref == item.ref,
                              orElse: () => continueItems.first,
                            );
                            return e.progress;
                          },
                          badgeFor: (item) {
                            final e = continueItems.firstWhere(
                              (x) => x.item.ref == item.ref,
                              orElse: () => continueItems.first,
                            );
                            return e.episodeLabel.isEmpty ? null : e.episodeLabel;
                          },
                          onSelect: (item) => context.openDetails(item.ref),
                        ),
                      ),
                    ...rows.map(
                      (row) => SliverToBoxAdapter(
                        child: MediaRow(
                          title: row.title,
                          subtitle: ui.showEcosystemBadges ? row.subtitle : null,
                          rowKey: row.key,
                          items: row.items,
                          formFactor: formFactor,
                          focusMemory: _focusMemory,
                          reduceMotion: ui.reduceMotion,
                          onSelect: (item) => context.openDetails(
                            item.ref,
                            sourceId: row.sourceId,
                            ecosystem: row.ecosystem,
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showAboutSources(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('About sources'),
        content: const SingleChildScrollView(
          child: Text(
            'Aero TV does not provide, host, or link to any content.\n\n'
            'It plays media from add-ons and plugins that you choose to '
            'install. You are responsible for ensuring you have the right to '
            'access anything you play.\n\n'
            'Five ecosystems are supported, each with its own manager in '
            'Settings → Extensions.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome({required this.formFactor});

  final FormFactor formFactor;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Shimmer(
          height: MediaQuery.sizeOf(context).height * 0.38,
          radius: 0,
        ),
        for (var i = 0; i < 3; i++)
          MediaRow(
            title: 'Loading…',
            items: const [],
            isLoading: true,
            formFactor: formFactor,
            onSelect: (_) {},
          ),
      ],
    );
  }
}
