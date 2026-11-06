import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../state/providers.dart';
import '../widgets/hero_from_row.dart';

/// One provider's own world: its hero, its categories, its ordering.
///
/// Opened from Browse. A SkyStream or Vega provider is a whole site, so it is
/// presented whole rather than flattened into Home alongside unrelated sites.
class ProviderHomeScreen extends ConsumerStatefulWidget {
  const ProviderHomeScreen({
    super.key,
    this.source,
    this.sourceId,
    this.ecosystemId,
  });

  final InstalledSource? source;
  final String? sourceId;
  final String? ecosystemId;

  @override
  ConsumerState<ProviderHomeScreen> createState() =>
      _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends ConsumerState<ProviderHomeScreen> {
  final _focusMemory = RowFocusMemory();
  InstalledSource? _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = widget.source;
    if (_resolved == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
    }
  }

  Future<void> _resolve() async {
    final all = await ref.read(installedSourcesProvider.future);
    final match = all
        .where((s) =>
            s.id == widget.sourceId &&
            (widget.ecosystemId == null ||
                s.ecosystem.id == widget.ecosystemId))
        .firstOrNull;
    if (mounted) setState(() => _resolved = match);
  }

  @override
  void dispose() {
    _focusMemory.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = _resolved ?? widget.source;
    final isTv = ref.watch(isTvProvider);
    final ui = ref.watch(uiSettingsProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);

    return Scaffold(
      appBar: AppBar(
        title: Text(source?.name ?? widget.sourceId ?? 'Provider'),
        actions: [
          if (source != null)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Manage this provider',
              onPressed: () =>
                  context.openExtensions(ecosystem: source.ecosystem),
            ),
        ],
      ),
      body: source == null
          ? const EmptyState(
              icon: Icons.help_outline_rounded,
              title: 'Provider not found',
              message: 'It may have been removed. Go back and pick another.',
            )
          : _Body(
              source: source,
              formFactor: formFactor,
              isTv: isTv,
              rotationSeconds: ui.heroRotationSeconds,
              focusMemory: _focusMemory,
            ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.source,
    required this.formFactor,
    required this.isTv,
    required this.rotationSeconds,
    required this.focusMemory,
  });

  final InstalledSource source;
  final FormFactor formFactor;
  final bool isTv;
  final int rotationSeconds;
  final RowFocusMemory focusMemory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceKey = source.key;
    final async = ref.watch(pluginHomeProvider(sourceKey));
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
        title: 'This provider failed to load',
        message: '$e',
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(pluginHomeProvider(sourceKey)),
        secondaryLabel: 'Diagnostics',
        onSecondary: () => context.openDiagnostics(source),
      ),
      data: (home) {
        if (home.error != null) {
          return EmptyState(
            icon: Icons.warning_amber_rounded,
            title: 'Could not open ${home.source.name}',
            message: home.error!,
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(pluginHomeProvider(sourceKey)),
            secondaryLabel: 'Diagnostics',
            onSecondary: () => context.openDiagnostics(home.source),
          );
        }
        if (home.isEmpty) {
          return EmptyState(
            icon: Icons.inbox_outlined,
            title: '${home.source.name} returned nothing',
            message: 'The provider loaded but its home feed is empty. '
                'The source site may be down or blocking requests.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(pluginHomeProvider(sourceKey)),
            secondaryLabel: 'Run diagnostics',
            onSecondary: () => context.openDiagnostics(home.source),
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
            await ref.read(pluginHomeProvider(sourceKey).future);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 4, pad, 14),
                child: Row(
                  children: [
                    EcosystemBadge(ecosystem: home.source.ecosystem, compact: true),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        home.source.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'v${home.source.version}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AeroColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
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
