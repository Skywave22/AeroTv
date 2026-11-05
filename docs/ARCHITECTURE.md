# Architecture

## Layering

```
UI (Flutter: adaptive mobile / TV / desktop)
 └─ Application (Riverpod providers, use-cases)
     └─ Domain (aero_core: unified models + EcosystemAdapter)
         └─ Ecosystem adapters
             ├─ StremioAdapter      (Dart + dio)
             ├─ VegaAdapter     ┐
             ├─ NuvioAdapter    ├─ JsPluginHost (QuickJS + Dart bridge)
             ├─ SkyStreamAdapter┘
             └─ CloudStreamAdapter  (Android-only channel client)
         └─ Data (Drift/SQLite, keystore, TTL cache)
 └─ Player (media_kit / libmpv)
```

**Rule:** `aero_core` imports no Flutter and does no I/O. That keeps the
resolver, ranker and ID mapping unit-testable in pure Dart, and prevents
ecosystem quirks from leaking into the UI.

## Why an adapter contract

All five ecosystems answer the same questions — what can you browse, what is
this title, where can I play it — but they disagree on transport, ID scheme and
function names. `EcosystemAdapter` is the seam. The UI never knows whether a
result came from HTTP JSON or a sandboxed scraper.

Adapters must be **defensive**: a broken third-party plugin returns an `Err` or
an empty page, never an exception that reaches the widget tree.

## Stream resolution

`StreamResolver.resolve()` returns a stream of events, not a Future:

```
ResolverStarted → ResolverProgress* → ResolverLink* → ResolverFinished
```

Design decisions:

- **Pre-filter before fanning out.** A source is skipped if it lacks the
  `streams` capability, doesn't serve the media type, or its `idPrefixes` don't
  match. This avoids pointless requests to IMDb-only add-ons for a TMDB title.
- **Per-source timeout (12 s) and overall deadline (25 s).** One slow add-on
  must never block playback.
- **Bounded concurrency (6).** Thirty parallel sockets will stall a cheap TV box.
- **De-duplicate by URL.** Two add-ons often return the same debrid link.
- **Contain errors per source** and report them in the sheet, so the user can
  see *why* a provider returned nothing.
- **Cancellation propagates.** Leaving the sheet aborts in-flight work.

## Ranking

`StreamRanker` is pure and deterministic, so it is fully unit-tested. Quality
dominates, then provider order, then language, then codec/HDR/size/latency.

Quality scoring is **asymmetric**: being one bucket below your preference costs
25 points, one bucket above costs 12. Preferring 1080p should still pick 4K over
480p when 1080p is unavailable.

Auto-play has a guard rail (`minScoreForAutoPlay`) so it never silently picks a
poor link.

## JS sandbox

Each plugin gets its own QuickJS context. The host shim replaces `fetch` and
`axios` with a message-channel transport, so **all** network I/O is performed by
Dart. That gives us one place to enforce:

- SSRF blocking (localhost, link-local, cloud metadata, private ranges, `.local`)
- scheme allow-list, optional HTTPS-only
- per-plugin concurrency cap and response-size cap
- logging of every destination to the in-app viewer

`eval`, `Function`, `XMLHttpRequest`, `WebSocket` and `setInterval` are removed.
Bundle SHA-256 is verified at install **and** at every boot.

The cheerio-compatible layer is a deliberately small subset. It is the highest
-risk part of the JS story — see the conformance work in Phase 2.

## Persistence

Drift/SQLite with nine tables. Generated code is **committed**, so CI never runs
`build_runner`; a CI step verifies it is not stale.

We pin `drift 2.31` + `sqlite3 2.x` + `sqlite3_flutter_libs 0.5.42` deliberately.
The newer `sqlite3` 3.x line moved to Dart native assets, which needs extra
toolchain setup on Android CI. This combination is boring and builds reliably.

Manifest-derived fields (capabilities, catalogs, idPrefixes) live in one JSON
blob column, so an upstream manifest change doesn't require a schema migration.

## TV focus

The two things most ports get wrong:

1. **Per-row focus memory.** `RowFocusMemory` remembers the last focused column
   in each row, so pressing Down then Up returns you to where you were.
2. **Real TV detection.** `UiModeManager` via a MethodChannel, with a leanback
   feature fallback for Fire TV — not a screen-size guess.

Plus overscan padding, no touch-only affordances, and remote key mapping.

## Deliberate omissions

- **No freezed / json_serializable / riverpod_generator.** Models are
  hand-written immutable Dart. This removes an entire class of CI failure
  (codegen drift) at the cost of some boilerplate. Only Drift uses codegen,
  and its output is committed.
- **No torrent engine.** Torrent-only streams are labelled, not played. A debrid
  add-on resolves them server-side into direct URLs, which we do play.
- **No native CloudStream host.** Licensing gate; see `docs/specs/cloudstream.md`.
