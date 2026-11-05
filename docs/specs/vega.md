# Vega plugin contract

> Full cross-ecosystem analysis, including the comparison table and the
> re-verification checklist: **[VERIFIED_CONTRACTS.md](VERIFIED_CONTRACTS.md)**.

**Status: VERIFIED 2026-11-05** against `vega-org/vega-app@main`
(`src/lib/providers/types.ts`, `ExtensionManager.ts`, `sandbox/protocol.ts`).

* Repository: `{sourceUrl}/manifest.json` — a JSON **array** of
  `{value, display_name, version, icon, disabled, type, hasSettings?, path?}`.
* A provider is **six files**, fetched from `{sourceUrl}/{path ?? dist/<value>}/`:
  required `posts`, `meta`, `stream`, `catalog`; optional `episodes`, `settings`.
* Functions return **promises** and take **one object argument**:
  `GetHomePosts({filter, page, providerValue, signal, providerContext})`,
  `GetSearchPosts({searchQuery, …})`, `GetMetaData({link, provider, …})`,
  `GetEpisodeLinks({url, …})`, `GetStream({link, type, …})`.
* `providerContext` supplies axios, cheerio, Crypto, `getBaseUrl`,
  `commonHeaders`, `openWebView`, `kvStore`, `getCookies`.
* Limits: module ≤ 2 MB, response ≤ 32 MB, state ≤ 256 KB, timeout 120 s.
* Capabilities: catalogs, search, meta, streams.

Implementation: `packages/eco_vega/lib/src/vega_provider.dart`, `vega_adapter.dart`.

> The previous provisional mapping used `getPosts`/`getMeta` with positional
> arguments. Both the names and the convention were wrong.
