import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';
import '../widgets/browse_search_overlay.dart';
import '../widgets/hero_from_row.dart';
import '../widgets/source_sheet.dart' show SourcePickerSheet;

/// Browse — SkyStream's own home, per provider.
///
/// This tab is deliberately not a plugin list any more. It reproduces what a
/// SkyStream user sees when they open the app: the selected provider's home
/// feed, its "Trending" category promoted to a hero, its remaining categories
/// as rows, and two controls in the corner — **source** (switch provider) and
/// **search**.
///
/// Which providers can appear here is decided by [BrowsePolicy] in `aero_core`:
/// SkyStream, Vega and CloudStream. Stremio add-ons fill Home instead, and
/// Nuvio scrapers only supply streams at play time, so neither is browsable.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _focusMemory = RowFocusMemory();

  @override
  void dispose() {
    _focusMemory.clear();
    super.dispose();
  }

  Future<void> _openSourceSheet() async {
    final sources = await ref.read(policyBrowsableSourcesProvider.future);
    if (!mounted) return;
    final currentKey = ref.read(activeBrowseSourceProvider).valueOrNull?.key;
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AeroColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SourcePickerSheet(
        sources: sources,
        selectedKey: currentKey,
      ),
    );
    if (picked == null || picked == currentKey) return;
    // Selecting a source also makes it the browsed provider everywhere.
    ref.read(browseSelectionProvider.notifier).state = picked;
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const BrowseSearchOverlay(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTv = ref.watch(isTvProvider);
    final ui = ref.watch(uiSettingsProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);
    final sourcesAsync = ref.watch(policyBrowsableSourcesProvider);
    final activeAsync = ref.watch(activeBrowseSourceProvider);

    return Scaffold(
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Shell(
          actions: _CornerActions(
            onSource: null,
            onSearch: _openSearch,
            sourceLabel: 'Source',
          ),
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load providers',
            message: '$e',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(installedSourcesProvider),
          ),
        ),
        data: (sources) {
          if (sources.isEmpty) {
            return _Shell(
              actions: _CornerActions(
                onSource: null,
                onSearch: null,
                sourceLabel: 'Source',
              ),
              child: EmptyState(
                icon: Icons.travel_explore_rounded,
                title: 'No providers to browse yet',
                message:
                    'Browse shows SkyStream, Vega and CloudStream providers — '
                    'each one a whole site with its own categories.\n\n'
                    'Stremio add-ons fill Home instead, and Nuvio scrapers '
                    'only supply streams when you press play.',
                actionLabel: 'Add a provider',
                onAction: () => context.openProviders(),
              ),
            );
          }

          final active = activeAsync.valueOrNull ?? sources.first;
          return _Shell(
            actions: _CornerActions(
              onSource: sources.length > 1 ? _openSourceSheet : null,
              onSearch: () => _openSearch(),
              sourceLabel: active.name,
            ),
            child: _ProviderHome(
              sourceKey: active.key,
              formFactor: formFactor,
              rotationSeconds: ui.heroRotationSeconds,
              reduceMotion: ui.reduceMotion,
              focusMemory: _focusMemory,
              onSwitchSource: _openSourceSheet,
              onSearch: _openSearch,
            ),
          );
        },
      ),
    );
  }
}

/// Shared chrome so the loading, empty and error states keep the corner
/// controls in the same place — on a TV a control that moves between states is
/// a control the user cannot find.
class _Shell extends StatelessWidget {
  const _Shell({required this.actions, required this.child});

  final Widget actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(top: 8, right: 12, child: actions),
        ],
      ),
    );
  }
}

/// The two corner controls SkyStream puts on its home: source and search.
class _CornerActions extends StatelessWidget {
  const _CornerActions({
    required this.onSource,
    required this.onSearch,
    required this.sourceLabel,
  });

  final VoidCallback? onSource;
  final VoidCallback? onSearch;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CornerButton(
          icon: Icons.swap_horiz_rounded,
          label: sourceLabel,
          onTap: onSource,
          tooltip: onSource == null
              ? 'The only provider installed'
              : 'Change source',
        ),
        const SizedBox(width: 8),
        _CornerButton(
          icon: Icons.search_rounded,
          label: null,
          onTap: onSearch,
          tooltip: 'Search this provider',
        ),
      ],
    );
  }
}

class _CornerButton extends StatelessWidget {
  const _CornerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TvFocus(
        borderRadius: 22,
        enabled: onTap != null,
        onSelect: onTap,
        child: Material(
          color: AeroColors.surfaceHigh.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: label == null ? 12 : 16,
                vertical: 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: onTap == null
                        ? AeroColors.textTertiary
                        : AeroColors.textPrimary,
                  ),
                  if (label != null) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        label!,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One provider's own world. The composition rule ("Trending" becomes the hero
/// and leaves the rows) lives in `pluginHomeProvider`, shared with every other
/// ecosystem that can produce a home feed.
class _ProviderHome extends ConsumerWidget {
  const _ProviderHome({
    required this.sourceKey,
    required this.formFactor,
    required this.rotationSeconds,
    required this.reduceMotion,
    required this.focusMemory,
    required this.onSwitchSource,
    required this.onSearch,
  });

  final String sourceKey;
  final FormFactor formFactor;
  final int rotationSeconds;
  final bool reduceMotion;
  final RowFocusMemory focusMemory;
  final VoidCallback onSwitchSource;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pluginHomeProvider(sourceKey));
    final pad = Adaptive.pagePadding(formFactor);

    return async.when(
      loading: () => ListView(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
        children: [
          Shimmer(height: formFactor == FormFactor.phone ? 200 : 320, radius: 16),
          const SizedBox(height: 24),
          for (var i = 0; i < 2; i++) ...[
            const Shimmer(width: 160, height: 18, radius: 4),
            const SizedBox(height: 12),
            SizedBox(
              height: PosterSkeleton.heightFor(Adaptive.posterWidth(formFactor)),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) =>
                    PosterSkeleton(width: Adaptive.posterWidth(formFactor)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'This provider failed to load',
        message: '$e',
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(pluginHomeProvider(sourceKey)),
        secondaryLabel: 'Switch source',
        onSecondary: onSwitchSource,
      ),
      data: (home) {
        if (home.error != null) {
          return EmptyState(
            icon: Icons.warning_amber_rounded,
            title: 'Could not open ${home.source.name}',
            message: home.error!,
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(pluginHomeProvider(sourceKey)),
            secondaryLabel: 'Switch source',
            onSecondary: onSwitchSource,
          );
        }
        if (home.isEmpty) {
          return EmptyState(
            icon: Icons.inbox_outlined,
            title: '${home.source.name} returned nothing',
            message: 'The provider loaded but its home feed is empty. '
                'The site may be down or blocking requests.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(pluginHomeProvider(sourceKey)),
            secondaryLabel: 'Search instead',
            onSecondary: onSearch,
          );
        }

        void open(MediaItem item) => context.openDetails(
              item.ref,
              sourceId: home.source.id,
              ecosystem: home.source.ecosystem,
            );

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pluginHomeProvider(sourceKey));
            try {
              await ref.read(pluginHomeProvider(sourceKey).future);
            } catch (_) {
              // Rendered by the error branch above.
            }
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (home.hero.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: HeroBanner(
                    items: pickHeroItems(home.hero),
                    formFactor: formFactor,
                    rotationSeconds: rotationSeconds,
                    reduceMotion: reduceMotion,
                    onPlay: open,
                    onMoreInfo: open,
                  ),
                )
              else
                SizedBox(height: pad),
              const SizedBox(height: 18),
              for (final row in home.rows)
                MediaRow(
                  rowKey: '${home.source.id}:${row.catalogId}',
                  title: row.title,
                  items: row.items,
                  formFactor: formFactor,
                  focusMemory: focusMemory,
                  reduceMotion: reduceMotion,
                  onSelect: open,
                ),
            ],
          ),
        );
      },
    );
  }
}
