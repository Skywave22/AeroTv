/// Builds a capability-aware "Run test" for any ecosystem adapter.
///
/// Lives in aero_core rather than the app so it can be exercised against a
/// fake adapter: the whole point is to verify the *branching* (stream-only
/// plugins, empty catalogues, a search that works but streams that do not),
/// which is exactly what a real plugin makes hard to reproduce.
library;

import '../adapter/ecosystem_adapter.dart';
import '../models/capability.dart';
import '../models/catalog.dart';
import '../models/media.dart';
import '../models/play_request.dart';
import '../models/source.dart';
import 'plugin_diagnostics.dart';

abstract final class AdapterDiagnostics {
  /// A deliberately common query. Zero hits is reported as "Empty", not a
  /// failure, so an unusual catalogue does not look broken.
  static const defaultQuery = 'star';

  static Future<DiagnosticReport> run(
    EcosystemAdapter adapter,
    InstalledSource source, {
    String query = defaultQuery,
    Duration perStepTimeout = const Duration(seconds: 30),
    bool stopOnFailure = false,
  }) async {
    // Probes run in order and hand state forward: browse needs a catalogue id,
    // streams need a real media ref from the browse result.
    List<CatalogRow> rows = const [];
    MediaItem? sample;

    Future<ProbeResult> reachable() async {
      final r = await adapter.healthCheck(source.id);
      return r.when(
        ok: (d) => ProbeResult(detail: '${d.inMilliseconds} ms round trip'),
        err: (e) => throw StateError(e),
      );
    }

    Future<ProbeResult> catalogues() async {
      rows = await adapter.catalogs(source.id);
      return ProbeResult(
        count: rows.length,
        detail: rows.isEmpty ? null : rows.map((r) => r.title).take(3).join(', '),
      );
    }

    Future<ProbeResult> browse() async {
      if (rows.isEmpty) {
        return const ProbeResult.skip('no catalogue to browse');
      }
      final row = rows.first;
      final page = await adapter.browse(
          source.id, row.catalogId, const CatalogQuery());
      if (page.items.isNotEmpty) sample = page.items.first;
      return ProbeResult(
        count: page.items.length,
        detail: sample == null ? null : 'first: ${sample!.title}',
      );
    }

    Future<ProbeResult> search() async {
      final page = await adapter.search(source.id, query);
      // A search hit is a better stream subject than a catalogue poster.
      if (page.items.isNotEmpty) sample = page.items.first;
      return ProbeResult(count: page.items.length, detail: 'query "$query"');
    }

    Future<ProbeResult> streams() async {
      if (sample == null) {
        // Nothing to resolve against: either the catalogue and search were
        // both empty, or this plugin supports neither. Not a stream failure.
        return const ProbeResult.skip('no title available to resolve');
      }
      final item = sample!;
      final links = await adapter
          .streams(source.id, PlayRequest(ref: item.ref))
          .take(20)
          .toList();
      return ProbeResult(
        count: links.length,
        detail: 'for ${item.title}',
      );
    }

    return PluginDiagnostics.run(
      source.key,
      perStepTimeout: perStepTimeout,
      stopOnFailure: stopOnFailure,
      probes: {
        'Reachable': reachable,
        'Catalogues': source.can(Capability.catalogs) ? catalogues : null,
        // Browsing needs a catalogue to browse. A plugin that declares
        // catalogs but returns none has nothing to browse, not a bug.
        'Browse': source.can(Capability.catalogs) ? browse : null,
        'Search': source.can(Capability.search) ? search : null,
        'Streams': source.can(Capability.streams) ? streams : null,
      },
    );
  }

  /// A stream-only source has no catalogue to find a title in, so the user
  /// supplies one. This is the "test with a known id" card: it is the only way
  /// to verify a Nuvio scraper, whose entire API is `getStreams`.
  ///
  /// [id] may be an IMDb id (`tt1160419`), a TMDB id (`438631` or
  /// `tmdb:438631`), or a provider-native id.
  static Future<DiagnosticReport> testStreams(
    EcosystemAdapter adapter,
    InstalledSource source, {
    required String id,
    MediaType type = MediaType.movie,
    int? season,
    int? episode,
    Duration perStepTimeout = const Duration(seconds: 30),
  }) {
    final ref = parseTestId(id, type: type);
    return PluginDiagnostics.run(
      source.key,
      perStepTimeout: perStepTimeout,
      probes: {
        'Streams': source.can(Capability.streams)
            ? () async {
                final links = await adapter
                    .streams(
                      source.id,
                      PlayRequest(
                        ref: ref,
                        season: season,
                        episode: episode,
                      ),
                    )
                    .take(20)
                    .toList();
                final playable = links.where((l) => l.isPlayable).length;
                return ProbeResult(
                  count: links.length,
                  detail: links.isEmpty
                      ? 'no links for ${ref.id}'
                      : '$playable playable, ${links.length - playable} other',
                );
              }
            : null,
      },
    );
  }

  /// Turns what the user typed into a ref, without guessing an IMDb id from a
  /// TMDB number or vice versa.
  static MediaRef parseTestId(String raw, {MediaType type = MediaType.movie}) {
    final text = raw.trim();
    final bare = text.startsWith('tmdb:') ? text.substring(5) : text;
    if (bare.startsWith('tt') && bare.length > 2) {
      return MediaRef(id: bare, type: type, imdbId: bare);
    }
    if (RegExp(r'^\d+$').hasMatch(bare)) {
      return MediaRef(id: 'tmdb:$bare', type: type, tmdbId: bare);
    }
    return MediaRef(id: text, type: type);
  }
}
