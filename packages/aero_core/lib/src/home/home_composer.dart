/// Builds the unified Home feed.
///
/// Home is metadata rows (TMDB) plus catalogue fragments from ecosystems whose
/// units merge — add-ons. Standalone providers (a SkyStream or Vega site) are
/// browsed one at a time instead, because flattening several whole sites into
/// one feed is incoherent.
///
/// Lives here rather than in the app so the ordering, capping and
/// failure-isolation rules can be tested without a widget tree.
library;

import '../models/capability.dart';
import '../models/catalog.dart';
import '../models/ecosystem.dart';
import '../models/media.dart';
import '../models/source.dart';

/// One rendered Home row. [ecosystem] is null for a metadata row, which has no
/// plugin behind it.
class HomeSection {
  const HomeSection({
    required this.key,
    required this.title,
    required this.sourceId,
    required this.catalogId,
    required this.items,
    this.ecosystem,
    this.subtitle,
  });

  final String key;
  final String title;
  final String sourceId;
  final String catalogId;
  final List<MediaItem> items;
  final Ecosystem? ecosystem;
  final String? subtitle;

  bool get isMetadata => ecosystem == null;
}

typedef CatalogFetcher = Future<List<CatalogRow>> Function(InstalledSource s);
typedef BrowseFetcher = Future<Page<MediaItem>> Function(
    InstalledSource s, String catalogId);

abstract final class HomeComposer {
  /// Sources that may contribute to Home, in priority order.
  ///
  /// Filtered by the ecosystem's [Ecosystem.mergesIntoHome] property and by
  /// declared capability, never by name.
  static List<InstalledSource> eligibleSources(
    List<InstalledSource> all, {
    Set<Ecosystem> unavailable = const {},
    int maxSources = 8,
  }) {
    final out = all
        .where((s) =>
            s.enabled &&
            s.ecosystem.mergesIntoHome &&
            !unavailable.contains(s.ecosystem) &&
            s.can(Capability.catalogs))
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return out.take(maxSources).toList();
  }

  /// Metadata rows first, then each source's catalogues in priority order.
  ///
  /// Every fetch is isolated: a source that throws, hangs or returns nothing
  /// is dropped without affecting the others. Rows from one source stay
  /// together and in the source's own catalogue order.
  static Future<List<HomeSection>> build({
    required List<InstalledSource> sources,
    required List<CatalogRow> metadataRows,
    required CatalogFetcher catalogs,
    required BrowseFetcher browse,
    Set<Ecosystem> unavailable = const {},
    Duration timeout = const Duration(seconds: 12),
    int maxSources = 8,
    int maxRowsPerSource = 3,
  }) async {
    final sections = <HomeSection>[
      for (final r in metadataRows)
        if (r.items.isNotEmpty)
          HomeSection(
            key: 'meta:${r.sourceId}:${r.catalogId}',
            title: r.title,
            sourceId: r.sourceId,
            catalogId: r.catalogId,
            items: r.items,
            subtitle: 'TMDB',
          ),
    ];

    final chosen =
        eligibleSources(sources, unavailable: unavailable, maxSources: maxSources);

    // Per-source slots so concurrent fetches cannot interleave one source's
    // rows into another's.
    final slots = List<List<HomeSection>>.generate(chosen.length, (_) => []);

    await Future.wait([
      for (var i = 0; i < chosen.length; i++)
        () async {
          final s = chosen[i];
          try {
            final rows = await catalogs(s).timeout(timeout);
            for (final c in rows.where((c) => c.isHomeEligible).take(maxRowsPerSource)) {
              try {
                final page = await browse(s, c.catalogId).timeout(timeout);
                if (page.items.isEmpty) continue;
                slots[i].add(HomeSection(
                  key: '${s.key}:${c.catalogId}',
                  title: c.title,
                  subtitle: s.name,
                  sourceId: s.id,
                  ecosystem: s.ecosystem,
                  catalogId: c.catalogId,
                  items: page.items,
                ));
              } catch (_) {
                // One failing catalogue does not sink the source.
              }
            }
          } catch (_) {
            // A failing source does not sink Home.
          }
        }(),
    ]);

    for (final slot in slots) {
      sections.addAll(slot);
    }
    return sections;
  }
}
