# Nuvio plugin contract

> Full cross-ecosystem analysis, including the comparison table and the
> re-verification checklist: **[VERIFIED_CONTRACTS.md](VERIFIED_CONTRACTS.md)**.

**Status: VERIFIED 2026-11-05** against `NuvioMedia/NuvioMobile@cmp-rewrite`
(`PluginModels.kt`, `PluginManifestParser.kt`, `JsBindings.kt`,
`PluginRepository.kt`) and `NuvioMedia/NuvioTV@dev` (`PluginRuntime.kt`).
**Both apps run the identical JS contract.**

* Repository: the pasted URL **is** `manifest.json`. Scraper code resolves to
  `manifestUrl.removeSuffix("/manifest.json") + "/" + filename`, or `filename`
  verbatim when it is absolute.
* Manifest: `{name, version, description?, author?, scrapers: [...]}`. Parser
  requires non-blank name and version and ≥ 1 scraper.
* **The entire plugin API is `getStreams(tmdbId, mediaType, season, episode)`**
  plus optional `onSettings()`. Resolved as
  `module.exports.getStreams || globalThis.getStreams`.
* Injected globals: `SCRAPER_ID`, `SCRAPER_SETTINGS`, `TMDB_API_KEY`.
* Result carries `seeders`, `peers`, `infoHash` — this ecosystem is
  **torrent-first**, so Aero emits torrent `StreamLink`s.
* **Capabilities: streams only.** No catalogs, no search, no metadata; Nuvio
  takes all of that from TMDB.

Implementation: `packages/eco_nuvio/lib/src/nuvio_scraper.dart`, `nuvio_adapter.dart`.

> The previous provisional mapping assumed `getHome`/`search`/`getDetail`.
> **None of those exist.** Offering to browse a Nuvio plugin would always show
> an empty screen, so the Browse tab excludes it by capability.

NuvioTV additionally supports `RepositoryType.EXTERNAL_DEX` (CloudStream `.cs3`).
That is a separate native path and stays behind Aero's CloudStream gate.
