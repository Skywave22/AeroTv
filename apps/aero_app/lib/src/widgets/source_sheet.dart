import 'dart:async';

import 'package:aero_core/aero_core.dart';
import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';

/// The source picker. Fills progressively as the resolver fans out, grouped by
/// ecosystem then provider, with quality/size/language badges.
class SourceSheet extends StatefulWidget {
  const SourceSheet({
    required this.events,
    required this.title,
    required this.onPick,
    this.rules = const RankingRules(),
    super.key,
  });

  final Stream<ResolverEvent> events;
  final String title;
  final void Function(StreamLink link) onPick;
  final RankingRules rules;

  static Future<void> show(
    BuildContext context, {
    required Stream<ResolverEvent> events,
    required String title,
    required void Function(StreamLink) onPick,
    RankingRules rules = const RankingRules(),
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        builder: (_) => SourceSheet(
          events: events,
          title: title,
          onPick: onPick,
          rules: rules,
        ),
      );

  @override
  State<SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<SourceSheet> {
  StreamSubscription<ResolverEvent>? _sub;
  final List<StreamLink> _links = [];
  final Map<String, SourceProgress> _progress = {};
  bool _finished = false;
  Duration? _elapsed;
  bool _autoPlayed = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.events.listen(_onEvent, onDone: () {
      if (mounted) setState(() => _finished = true);
    });
  }

  void _onEvent(ResolverEvent ev) {
    if (!mounted) return;
    setState(() {
      switch (ev) {
        case ResolverStarted():
          break;
        case ResolverProgress(:final progress):
          _progress[progress.source.key] = progress;
        case ResolverLink(:final link):
          _links.add(link);
          // Auto-play the first link that clears the user's guard rail.
          if (!_autoPlayed && widget.rules.autoPlayEnabled) {
            final best = StreamRanker(widget.rules).bestForAutoPlay(_links);
            if (best != null) {
              _autoPlayed = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.of(context).pop();
                widget.onPick(best.link);
              });
            }
          }
        case ResolverFinished(:final elapsed):
          _finished = true;
          _elapsed = elapsed;
      }
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ranked = StreamRanker(widget.rules).rank(_links);
    final grouped = StreamResolver.group(ranked.map((r) => r.link));
    final working =
        _progress.values.where((p) => p.status == SourceStatus.resolving).length;
    final torrentCount = _links.where((l) => l.isTorrent && !l.isPlayable).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose a source',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AeroColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                if (!_finished)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                MetaChip(
                  label: '${ranked.length} playable',
                  tone: ranked.isEmpty ? MetaChipTone.neutral : MetaChipTone.success,
                ),
                const SizedBox(width: 6),
                if (working > 0) MetaChip(label: '$working searching…'),
                if (_finished && _elapsed != null) ...[
                  const SizedBox(width: 6),
                  MetaChip(label: '${_elapsed!.inMilliseconds} ms'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (ranked.isEmpty && _finished)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: EmptyState(
                      icon: Icons.link_off_rounded,
                      title: 'No playable sources',
                      message: torrentCount > 0
                          ? 'Found $torrentCount torrent-only result(s). Aero TV '
                              'plays direct URLs — add a debrid add-on to '
                              'resolve torrents into direct links.'
                          : 'None of your enabled sources returned a playable '
                              'link for this title.',
                      compact: true,
                    ),
                  )
                else if (ranked.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                for (final eco in grouped.keys) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: EcosystemBadge(ecosystem: eco),
                  ),
                  for (final provider in grouped[eco]!.keys)
                    ...grouped[eco]![provider]!.map((link) => _StreamTile(
                          link: link,
                          score: ranked
                              .firstWhere(
                                (r) => r.link.url == link.url,
                                orElse: () => RankedStream(link: link, score: 0),
                              )
                              .score,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onPick(link);
                          },
                        )),
                ],
                if (_progress.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: SectionHeader(
                      title: 'Source status',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  ..._progress.values.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              switch (p.status) {
                                SourceStatus.done => Icons.check_circle_rounded,
                                SourceStatus.resolving => Icons.refresh_rounded,
                                SourceStatus.failed => Icons.error_rounded,
                                SourceStatus.timedOut => Icons.timer_off_rounded,
                                SourceStatus.empty => Icons.remove_circle_outline,
                                _ => Icons.schedule_rounded,
                              },
                              size: 14,
                              color: switch (p.status) {
                                SourceStatus.done => AeroColors.success,
                                SourceStatus.failed => AeroColors.danger,
                                SourceStatus.timedOut => AeroColors.warning,
                                _ => AeroColors.textTertiary,
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.source.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              p.label,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AeroColors.textTertiary,
                                  ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamTile extends StatelessWidget {
  const _StreamTile({
    required this.link,
    required this.score,
    required this.onTap,
  });

  final StreamLink link;
  final int score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: TvFocus(
        onSelect: onTap,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: AeroColors.surface,
          leading: Icon(
            switch (link.kind) {
              StreamKind.hls => Icons.stream_rounded,
              StreamKind.dash => Icons.dashboard_customize_outlined,
              _ => Icons.play_circle_outline_rounded,
            },
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            link.title ?? link.sourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                if (link.quality != Quality.unknown)
                  MetaChip(
                    label: link.quality.label,
                    tone: link.quality.height >= 1080
                        ? MetaChipTone.accent
                        : MetaChipTone.neutral,
                  ),
                if (link.sizeLabel != null) MetaChip(label: link.sizeLabel!),
                if (link.language != null)
                  MetaChip(label: link.language!.toUpperCase()),
                if (link.isHdr) const MetaChip(label: 'HDR', tone: MetaChipTone.warning),
                if (link.codec != null) MetaChip(label: link.codec!),
                if (link.debrid)
                  const MetaChip(label: 'debrid', tone: MetaChipTone.success),
                if (link.kind == StreamKind.hls) const MetaChip(label: 'HLS'),
                if (link.kind == StreamKind.dash) const MetaChip(label: 'DASH'),
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AeroColors.textTertiary,
                    ),
              ),
              Text(
                'score',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: AeroColors.textTertiary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks which provider Browse is showing.
///
/// The corner "source" control on the Browse tab opens this — the same control
/// SkyStream puts on its own home. It lists only the providers that can
/// actually be browsed (see `BrowsePolicy`), plus a row for every ecosystem
/// that is deliberately not here, with the reason — so a user who wonders where
/// their add-ons went gets an answer instead of a blank tab.
class SourcePickerSheet extends StatelessWidget {
  const SourcePickerSheet({
    required this.sources,
    this.selectedKey,
    this.onManage,
    super.key,
  });

  final List<InstalledSource> sources;
  final String? selectedKey;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final absent = [
      for (final eco in Ecosystem.values)
        if (BrowsePolicy.absentReason(eco) case final reason?)
          (ecosystem: eco, reason: reason),
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Source',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (onManage != null)
                    TextButton.icon(
                      onPressed: onManage,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Manage'),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  for (final s in sources)
                    _PickerRow(
                      title: s.name,
                      subtitle: '${s.ecosystem.displayName} · v${s.version}',
                      tint: Color(s.ecosystem.colorSeed),
                      logo: s.logo,
                      selected: s.key == selectedKey,
                      onTap: () => Navigator.of(context).pop(s.key),
                    ),
                  if (absent.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 16, 8, 6),
                      child: Divider(height: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Text(
                        'Not browsable',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AeroColors.textTertiary),
                      ),
                    ),
                    for (final a in absent)
                      _PickerRow(
                        title: a.ecosystem.displayName,
                        subtitle: a.reason,
                        tint: Color(a.ecosystem.colorSeed),
                        logo: null,
                        selected: false,
                        onTap: null,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.logo,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color tint;
  final String? logo;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: TvFocus(
        borderRadius: 12,
        enabled: enabled,
        onSelect: onTap,
        child: Material(
          color: selected
              ? tint.withValues(alpha: 0.16)
              : AeroColors.surfaceHigh.withValues(alpha: enabled ? 1 : 0.5),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: tint.withValues(alpha: 0.2),
                    backgroundImage: logo == null ? null : NetworkImage(logo!),
                    child: logo == null
                        ? Icon(Icons.extension_rounded, size: 16, color: tint)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: enabled
                                ? AeroColors.textPrimary
                                : AeroColors.textSecondary,
                          ),
                        ),
                        Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AeroColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  if (selected) Icon(Icons.check_rounded, color: tint, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
