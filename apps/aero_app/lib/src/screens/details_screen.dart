import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:aero_data/aero_data.dart';
import 'package:aero_player/aero_player.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../state/providers.dart';
import '../widgets/source_sheet.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({required this.args, super.key});

  final DetailsArgs args;

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  int? _season;
  bool _inWatchlist = false;
  bool _inFavorites = false;
  Color? _accent;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLibraryFlags();
  }

  Future<void> _loadLibraryFlags() async {
    final repo = ref.read(libraryRepoProvider);
    final key = widget.args.ref.cacheKey;
    final w = await repo.contains(key, LibraryLists.watchlist);
    final f = await repo.contains(key, LibraryLists.favorites);
    if (mounted) setState(() { _inWatchlist = w; _inFavorites = f; });
  }

  /// Extracts a dominant colour from the artwork to tint the page.
  Future<void> _extractPalette(String url) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(url),
        maximumColorCount: 8,
        size: const Size(120, 180),
      ).timeout(const Duration(seconds: 4));
      final color = palette.darkVibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.vibrantColor?.color;
      if (color != null && mounted) setState(() => _accent = color);
    } catch (_) {
      // Palette extraction is cosmetic; ignore failures.
    }
  }

  Future<void> _resolveAndPlay({MediaItem? item, EpisodeRef? episode}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final details = await ref.read(detailsProvider(widget.args).future);
      final media = item ?? details?.item;
      if (media == null) return;

      final resolver = ref.read(metadataResolverProvider);
      final enriched = await resolver.enrich(media.ref);

      final req = PlayRequest(
        ref: enriched,
        season: episode?.season,
        episode: episode?.episode,
        episodeId: episode?.id,
      );

      final rules = ref.read(rankingRulesProvider);
      final streamResolver = ref.read(streamResolverProvider);
      final title = episode == null
          ? media.title
          : '${media.title} · ${episode.label}';

      if (!mounted) return;
      await SourceSheet.show(
        context,
        events: streamResolver.resolve(req),
        title: title,
        rules: rules,
        onPick: (link) => _openPlayer(
          link: link,
          item: media,
          episode: episode,
          request: req,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Returns true to resume, false to start over, null if dismissed.
  Future<bool?> _confirmResume(Duration position) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resume playback?'),
        content: Text(
          'You stopped at ${formatDuration(position)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Start over'),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Resume ${formatDuration(position)}'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPlayer({
    required StreamLink link,
    required MediaItem item,
    required PlayRequest request,
    EpisodeRef? episode,
  }) async {
    final playerSettings = ref.read(playerSettingsProvider);
    final isTv = ref.read(isTvProvider);
    final history = ref.read(historyRepoProvider);

    var start = Duration.zero;
    if (playerSettings.resumePlayback) {
      final resume = await history.resumePoint(
        item.ref.cacheKey,
        season: episode?.season,
        episode: episode?.episode,
      );
      if (resume != null && resume.isResumable) {
        start = Duration(milliseconds: resume.positionMs);
        // Ask rather than silently jumping: the user may be rewatching, and a
        // surprise seek is disorienting. Autofocus Resume so a remote user can
        // just press Select.
        if (mounted) {
          final resumeIt = await _confirmResume(start);
          if (resumeIt == null) return; // dismissed: do not start playback
          if (!resumeIt) start = Duration.zero;
        }
      }
    }

    // Fetch external subtitles in the background; don't block playback.
    final subs = <SubtitleTrack>[];
    unawaited(() async {
      try {
        final registry = ref.read(adapterRegistryProvider);
        final sources = await ref.read(installedSourcesProvider.future);
        for (final s in sources.where((s) => s.enabled && s.can(Capability.subtitles))) {
          final adapter = registry.forEcosystem(s.ecosystem);
          if (adapter == null || !adapter.isAvailable) continue;
          final list = await adapter
              .subtitles(s.id, request)
              .timeout(const Duration(seconds: 8));
          subs.addAll(list);
        }
      } catch (_) {
        // Subtitles are optional.
      }
    }());

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PlayerScreen(
          link: link,
          title: item.title,
          subtitle: episode?.label,
          startPosition: start,
          hardwareDecoding: playerSettings.hardwareDecoding,
          defaultSubtitleLang: playerSettings.defaultSubtitleLang,
          subtitlesEnabled: playerSettings.subtitlesEnabledByDefault,
          preferredAudioLang: playerSettings.preferredAudioLang,
          isTv: isTv,
          externalSubtitles: subs,
          onProgress: (position, duration) {
            if (duration.inSeconds <= 0) return;
            unawaited(history.record(
              item: item,
              positionMs: position.inMilliseconds,
              durationMs: duration.inMilliseconds,
              season: episode?.season,
              episode: episode?.episode,
            ));
          },
          onTryAnotherSource: () {
            Navigator.of(context).maybePop();
            unawaited(_resolveAndPlay(item: item, episode: episode));
          },
        ),
      ),
    );
    // Refresh Continue Watching after returning from the player.
    ref.invalidate(continueWatchingProvider);
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(detailsProvider(widget.args));
    final ui = ref.watch(uiSettingsProvider);
    final isTv = ref.watch(isTvProvider);
    final formFactor = Adaptive.detect(context, isTv: isTv);

    return Scaffold(
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load details',
          message: '$e',
          actionLabel: 'Go back',
          onAction: () => Navigator.of(context).maybePop(),
        ),
        data: (details) {
          if (details == null) {
            return const EmptyState(
              icon: Icons.movie_filter_outlined,
              title: 'No details available',
              message: 'None of your add-ons provided metadata for this title.',
            );
          }
          final item = details.item;
          final art = item.background ?? item.poster;
          if (art != null && _accent == null && ui.dynamicColorFromArtwork) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _extractPalette(art));
          }
          final seasons = details.seasons;
          final activeSeason = _season ?? (seasons.isNotEmpty ? seasons.first : null);
          final episodes = activeSeason == null
              ? const <EpisodeRef>[]
              : details.episodesOfSeason(activeSeason);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: Adaptive.heroHeight(formFactor, MediaQuery.sizeOf(context)) * 0.85,
                pinned: true,
                backgroundColor: AeroColors.background,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (art != null)
                        CachedNetworkImage(
                          imageUrl: art,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          memCacheWidth: 1280,
                          errorWidget: (_, _, _) =>
                              const ColoredBox(color: AeroColors.surfaceHigh),
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: AeroColors.heroScrim,
                            stops: [0.2, 0.55, 1.0],
                          ),
                        ),
                      ),
                      if (_accent != null)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _accent!.withValues(alpha: 0.30),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: Theme.of(context).textTheme.displayMedium),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (item.year != null) MetaChip(label: '${item.year}'),
                          if (item.imdbRating != null)
                            MetaChip(
                              label: '★ ${item.imdbRating!.toStringAsFixed(1)}',
                              tone: MetaChipTone.warning,
                            ),
                          if (item.runtime != null) MetaChip(label: item.runtime!),
                          if (details.certification != null)
                            MetaChip(label: details.certification!),
                          ...item.genres.take(4).map((g) => MetaChip(label: g)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          AeroPrimaryButton(
                            label: details.isSeries ? 'Play S01E01' : 'Play',
                            icon: Icons.play_arrow_rounded,
                            autofocus: isTv,
                            onPressed: _busy
                                ? null
                                : () => _resolveAndPlay(
                                      item: item,
                                      episode: details.isSeries && episodes.isNotEmpty
                                          ? episodes.first
                                          : null,
                                    ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            tooltip: _inWatchlist ? 'In watchlist' : 'Add to watchlist',
                            icon: Icon(_inWatchlist
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded),
                            onPressed: () async {
                              await ref
                                  .read(libraryRepoProvider)
                                  .toggle(item, LibraryLists.watchlist);
                              await _loadLibraryFlags();
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: _inFavorites ? 'Favorited' : 'Add to favorites',
                            icon: Icon(_inFavorites
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded),
                            onPressed: () async {
                              await ref
                                  .read(libraryRepoProvider)
                                  .toggle(item, LibraryLists.favorites);
                              await _loadLibraryFlags();
                            },
                          ),
                        ],
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      if (item.description != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          item.description!,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AeroColors.textSecondary,
                              ),
                        ),
                      ],
                      if (details.cast.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Cast: ${details.cast.take(6).join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AeroColors.textTertiary,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (details.isSeries && seasons.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                    child: Row(
                      children: [
                        Text('Episodes',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        DropdownButton<int>(
                          value: activeSeason,
                          underline: const SizedBox.shrink(),
                          items: seasons
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('Season $s'),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _season = v),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: episodes.length,
                  itemBuilder: (context, i) {
                    final ep = episodes[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      child: TvFocus(
                        onSelect: () => _resolveAndPlay(item: item, episode: ep),
                        child: ListTile(
                          onTap: () => _resolveAndPlay(item: item, episode: ep),
                          tileColor: AeroColors.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          leading: ep.thumbnail == null
                              ? CircleAvatar(
                                  backgroundColor: AeroColors.surfaceHigher,
                                  child: Text('${ep.episode}'),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: ep.thumbnail!,
                                    width: 96,
                                    height: 54,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 200,
                                    errorWidget: (_, _, _) => Container(
                                      width: 96,
                                      height: 54,
                                      color: AeroColors.surfaceHigher,
                                    ),
                                  ),
                                ),
                          title: Text(
                            ep.title ?? 'Episode ${ep.episode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: ep.overview == null
                              ? Text(ep.label)
                              : Text(
                                  '${ep.label} · ${ep.overview}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: const Icon(Icons.play_circle_outline_rounded),
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}
