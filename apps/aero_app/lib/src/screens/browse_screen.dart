import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';
import '../widgets/hero_from_row.dart';

/// Browse — one plugin's own world.
///
/// Home merges every ecosystem into one feed. Browse does the opposite: you
/// pick a single plugin and see *its* categories, *its* hero and *its*
/// ordering, exactly as that ecosystem's own app presents it.
///
/// Plugins that cannot supply a home feed (Nuvio scrapers are streams-only)
/// are listed separately with the reason, rather than silently missing.
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

  @override
  Widget build(BuildContext context) {
    final isTv = ref.watch(isTvProvider);
    final ui = ref.watch(uiSettingsProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);
    final sourcesAsync = ref.watch(browsableSourcesProvider);

    return Scaffold(
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load your plugins',
          message: '$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(browsableSourcesProvider),
        ),
        data: (sources) {
          if (sources.isEmpty) return const _NoBrowsablePlugins();

          final selected = ref.watch(browseSelectionProvider);
          final activeId =
              sources.any((s) => s.id == selected) ? selected! : sources.first.id;

          return Column(
            children: [
              _PluginPicker(
                sources: sources,
                activeId: activeId,
                formFactor: formFactor,
                onSelect: (id) =>
                    ref.read(browseSelectionProvider.notifier).state = id,
              ),
              Expanded(
                child: _PluginBody(
                  sourceId: activeId,
                  formFactor: formFactor,
                  isTv: isTv,
                  rotationSeconds: ui.heroRotationSeconds,
                  focusMemory: _focusMemory,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Horizontal plugin selector. On TV it is D-pad traversable and each chip
/// carries its ecosystem colour so the active world is always obvious.
class _PluginPicker extends StatelessWidget {
  const _PluginPicker({
    required this.sources,
    required this.activeId,
    required this.formFactor,
    required this.onSelect,
  });

  final List<InstalledSource> sources;
  final String activeId;
  final FormFactor formFactor;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tv = formFactor == FormFactor.tv;
    return SizedBox(
      height: tv ? 76 : 62,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(
            Adaptive.pagePadding(formFactor),
            tv ? 16 : 10,
            Adaptive.pagePadding(formFactor),
            tv ? 16 : 10,
          ),
          itemCount: sources.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final s = sources[i];
            final selected = s.id == activeId;
            return TvFocus(
              borderRadius: 24,
              child: ChoiceChip(
                selected: selected,
                onSelected: (_) => onSelect(s.id),
                avatar: CircleAvatar(
                  radius: 9,
                  backgroundColor: Color(s.ecosystem.colorSeed),
                ),
                label: Text(
                  s.name,
                  style: TextStyle(fontSize: tv ? 17 : 14),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PluginBody extends ConsumerWidget {
  const _PluginBody({
    required this.sourceId,
    required this.formFactor,
    required this.isTv,
    required this.rotationSeconds,
    required this.focusMemory,
  });

  final String sourceId;
  final FormFactor formFactor;
  final bool isTv;
  final int rotationSeconds;
  final RowFocusMemory focusMemory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pluginHomeProvider(sourceId));
    final pad = Adaptive.pagePadding(formFactor);

    return async.when(
      loading: () => ListView(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
        children: [
          Shimmer(
            height: formFactor == FormFactor.phone ? 200 : 320,
            radius: 16,
          ),
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
                itemBuilder: (_, _) => PosterSkeleton(
                  width: Adaptive.posterWidth(formFactor),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'This plugin failed to load',
        message: '$e',
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(pluginHomeProvider(sourceId)),
      ),
      data: (home) {
        if (home.error != null) {
          return EmptyState(
            icon: Icons.warning_amber_rounded,
            title: 'Could not open ${home.source.name}',
            message: home.error!,
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(pluginHomeProvider(sourceId)),
            secondaryLabel: 'Manage plugins',
            onSecondary: () => context.openExtensions(),
          );
        }
        if (home.isEmpty) {
          return EmptyState(
            icon: Icons.inbox_outlined,
            title: '${home.source.name} returned nothing',
            message: 'The plugin loaded but its home feed is empty. '
                'The source site may be down or blocking requests.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(pluginHomeProvider(sourceId)),
          );
        }

        void open(MediaItem item) => context.openDetails(
              item.ref,
              sourceId: home.source.id,
              ecosystem: home.source.ecosystem,
            );

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pluginHomeProvider(sourceId));
            await ref.read(pluginHomeProvider(sourceId).future);
          },
          child: ListView(
            padding: EdgeInsets.only(bottom: 32),
            children: [
              _SourceHeader(source: home.source, formFactor: formFactor),
              if (home.hero.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: HeroBanner(
                    items: pickHeroItems(home.hero),
                    formFactor: formFactor,
                    rotationSeconds: rotationSeconds,
                    reduceMotion: isTv,
                    onPlay: open,
                    onMoreInfo: open,
                  ),
                ),
              const SizedBox(height: 20),
              for (final row in home.rows)
                MediaRow(
                  rowKey: '${home.source.id}:${row.catalogId}',
                  title: row.title,
                  items: row.items,
                  formFactor: formFactor,
                  focusMemory: focusMemory,
                  reduceMotion: isTv,
                  onSelect: open,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Names the world you are in, so a plugin's content is never mistaken for
/// another's. Also the entry point to that plugin's own settings.
class _SourceHeader extends StatelessWidget {
  const _SourceHeader({required this.source, required this.formFactor});

  final InstalledSource source;
  final FormFactor formFactor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Adaptive.pagePadding(formFactor),
        4,
        Adaptive.pagePadding(formFactor),
        14,
      ),
      child: Row(
        children: [
          EcosystemBadge(ecosystem: source.ecosystem, compact: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              source.name,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'v${source.version}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AeroColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoBrowsablePlugins extends ConsumerWidget {
  const _NoBrowsablePlugins();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nonBrowsable = ref.watch(nonBrowsableSourcesProvider).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      children: [
        EmptyState(
          icon: Icons.travel_explore_outlined,
          title: 'Nothing to browse yet',
          message: 'Browse shows one plugin at a time, using that plugin\'s own '
              'categories and layout. Install a Stremio, SkyStream or Vega '
              'plugin to get started.',
          actionLabel: 'Add a plugin',
          onAction: () => context.openExtensions(),
        ),
        if (nonBrowsable.isNotEmpty) ...[
          const SizedBox(height: 28),
          const SectionHeader(title: 'Installed, but not browsable'),
          const SizedBox(height: 8),
          for (final s in nonBrowsable)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(s.ecosystem.colorSeed).withValues(alpha: 0.18),
                  child: Icon(Icons.bolt_rounded, color: Color(s.ecosystem.colorSeed)),
                ),
                title: Text(s.name),
                subtitle: Text(
                  '${s.ecosystem.displayName} plugins only supply streams. '
                  'They appear in the source picker when you play something.',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ],
    );
  }
}
