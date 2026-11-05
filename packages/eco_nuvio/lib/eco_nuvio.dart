/// Nuvio scraper adapter — **streams only**, TMDB-keyed.
///
/// Contract verified against NuvioMedia/NuvioMobile@cmp-rewrite and
/// NuvioMedia/NuvioTV@dev on 2026-11-05. Both run the same QuickJS contract:
/// `getStreams(tmdbId, mediaType, season, episode)` and optional `onSettings`.
/// See docs/specs/VERIFIED_CONTRACTS.md.
library;

export 'src/nuvio_scraper.dart';
export 'src/nuvio_adapter.dart';
