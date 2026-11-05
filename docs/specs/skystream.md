# SkyStream plugin contract

> Full cross-ecosystem analysis, including the comparison table and the
> re-verification checklist: **[VERIFIED_CONTRACTS.md](VERIFIED_CONTRACTS.md)**.

**Status: VERIFIED 2026-11-05** against `akashdh11/skystream@master` and
`skystream-tools@main/DEVELOPER.md`.

* Manifest: `plugin.json` — `packageName`, `name`, `version` (**int**), `baseUrl`,
  `languages`, `categories`; optional `domains[]` mirrors and `providers[]`
  sub-feeds (mutually exclusive).
* Functions, **callback-style**, exported on `globalThis`:
  `getHome(cb)`, `search(query, page, cb)`, `load(url, cb)`, `loadStreams(url, cb)`.
* Envelope `{success, data, errorCode, message}`.
* `getHome` returns `{Category: [MultimediaItem]}`. `"Trending"` is **reserved**
  for the hero carousel and is removed from the rows below; if absent the first
  category is promoted.
* Capabilities: catalogs, search, meta, streams.

Implementation: `packages/eco_skystream/lib/src/skystream_provider.dart` (native
shapes), `js_skystream_provider.dart` (callback bridge), `skystream_adapter.dart`.

> The previous provisional mapping called `loadLinks`. That function does not
> exist upstream — it is `loadStreams`.
