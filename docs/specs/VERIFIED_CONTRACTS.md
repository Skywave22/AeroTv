# Verified ecosystem contracts (Phase 0 — complete)

Every claim below was read from upstream source on **2026-11-05**. File paths and
branches are recorded so the next person can re-verify instead of guessing.

| Repo | Branch read | Language |
|---|---|---|
| `akashdh11/skystream` | `master` | Dart |
| `akashdh11/skystream-tools` | `main` (`DEVELOPER.md`) | docs |
| `NuvioMedia/NuvioMobile` | `cmp-rewrite` | Kotlin Multiplatform |
| `NuvioMedia/NuvioTV` | `dev` | Kotlin |
| `vega-org/vega-app` | `main` | TypeScript / React Native |

## The headline finding

**These ecosystems are not variations of one interface.** They differ in
*calling convention*, *module layout*, and *capability surface*. The previous
`JsDialect` object — which only renamed functions — could not express any of
them correctly. It has been replaced by one first-class provider interface per
ecosystem, mirroring upstream.

| | SkyStream | Vega | Nuvio |
|---|---|---|---|
| Convention | **callback** `fn(args…, cb)` | **Promise**, single **object** arg | **Promise**, positional args |
| Module layout | one `plugin.js` | **6 separate `.js` files** | one file per scraper |
| Repository index | `repo.json` | `manifest.json` (**array**) | `manifest.json` (**object**) |
| Home / catalog | ✅ `getHome` | ✅ `GetHomePosts` + `catalog` | ❌ **none** |
| Search | ✅ `search` | ✅ `GetSearchPosts` | ❌ **none** |
| Details | ✅ `load` | ✅ `GetMetaData` | ❌ **none** |
| Streams | ✅ `loadStreams` | ✅ `GetStream` | ✅ `getStreams` |
| Metadata key | source URL | source link | **TMDB id** |

The single most consequential correction: **Nuvio plugins are source-only.**
They export `getStreams` and nothing else. Nuvio gets all of its catalog,
search, and metadata from TMDB. Any Aero UI that offers "browse a Nuvio plugin"
would be offering something that cannot work.

---

## 1. SkyStream

Sources: `lib/core/extensions/base_provider.dart`, `assets/plugins/plugin.js`,
`skystream-tools/DEVELOPER.md`.

### Manifest — `plugin.json`

```json
{
  "packageName": "dev.akash.stars.template",
  "name": "template",
  "version": 1,
  "baseUrl": "https://example.com",
  "description": "…",
  "authors": ["Developer"],
  "languages": ["en"],
  "categories": ["Others"]
}
```

`version` is an **integer**, not semver. Optional advanced keys:

* `domains: [{name, url}]` — mirror picker. The chosen URL is injected as
  `manifest.baseUrl`; plugin code never changes.
* `providers: [{id, name, baseUrl?}]` — sub-providers, one JS many feeds. When
  `baseUrl` is omitted the app injects `manifest.providerId` and the plugin
  resolves its own URL. **Cannot be combined with `domains`.**

### Functions — all callback-style, exported on `globalThis`

```js
async function getHome(cb)                  // → {success, data: {Category: [Item]}}
async function search(query, page, cb)      // → {success, data: [Item]}
async function load(url, cb)                // → {success, data: Item}
async function loadStreams(url, cb)         // → {success, data: [StreamResult]}
globalThis.getHome = getHome;               // …etc
```

Envelope: `{success: bool, data?: any, errorCode?: string, message?: string}`.
`manifest` is injected at runtime — plugins must use `manifest.baseUrl`, never a
hardcoded domain.

> The earlier provisional adapter called `loadLinks`. **That function does not
> exist.** It is `loadStreams`.

### Dashboard rule (this is what the new Browse tab reproduces)

| Category name | Behaviour |
|---|---|
| `"Trending"` | **Reserved.** Promoted to the hero carousel, and *removed* from the rows below to avoid duplication. |
| anything else | Horizontal thumbnail row. |
| no `"Trending"` | The **first** category is used for the carousel. |

### Shapes

`MultimediaItem` — required `title`, `url`, `posterUrl`, `type`
(`movie|series|anime|livestream`). Optional `year`, `score`, `duration`
(minutes), `status` (`ongoing|completed|upcoming`), `logoUrl`, `bannerUrl`,
`contentRating`, `playbackPolicy`, `isAdult`, `description`, `tags`, `cast`,
`trailers`, `nextAiring`, `recommendations`, `syncData`, `headers`, `episodes`,
and `streams` ("instant load" — bypasses `loadStreams`).

`Episode` — required `name`, `url`, `season`, `episode`. Optional `rating`,
`runtime`, `airDate`, `dubStatus` (`none|dubbed|subbed`), `posterUrl`,
`description`, `headers`, `streams`.

`StreamResult` — required `url`. Optional `source` (display name, default
`"Auto"`), `quality` (number **or** string: `1080`, `"1080p"`, `"4K"`/`"UHD"`,
`"2K"`/`"1440p"`, `"Auto"`/`0` = HLS master), `headers`,
`subtitles: [{url, label, lang}]`, `drmKid`, `licenseUrl`.

### Host helpers

`solveCaptcha(siteKey, url)`, `crypto.decryptAES(data, key, iv)`,
`parse_html(html, selector, attr)`, `getAndUnpack(js)`,
`http_parallel(requests)`. Per-function budget is **90 seconds**.

---

## 2. Vega

Sources: `src/lib/providers/types.ts`, `src/lib/services/ExtensionManager.ts`,
`src/lib/storage/extensionStorage.ts`, `src/lib/sandbox/protocol.ts`.

### Repository index — `{sourceUrl}/manifest.json`, a JSON **array**

```json
[{ "value": "providerid", "display_name": "Provider", "version": "1.0.0",
   "icon": "…", "disabled": false, "type": "global",
   "hasSettings": false, "path": "optional/folder" }]
```

`type` ∈ `global | english | india | italy | anime | drama`.
`path` overrides the default folder; it is validated so it cannot escape the
source directory.

### Module layout — six files, not one

Fetched from `{sourceUrl}/{path ?? "dist/" + value}/{name}.js`:

* **required**: `posts`, `meta`, `stream`, `catalog`
* **optional**: `episodes`, `settings`

Limits from `protocol.ts`: module ≤ 2 MB, response ≤ 32 MB, state ≤ 256 KB,
invoke timeout 120 s.

### Functions — Promise-returning, one destructured object argument

```ts
catalog:      Catalog[] | (args?) => Promise<Catalog[]>   // {title, filter}
genres:       CatalogList
GetHomePosts({filter, page, providerValue, signal, providerContext}): Promise<Post[]>
GetSearchPosts({searchQuery, page, providerValue, signal, providerContext}): Promise<Post[]>
GetMetaData({link, provider, providerContext}): Promise<Info>
GetEpisodeLinks({url, providerContext}): Promise<EpisodeLink[]>   // optional
GetStream({link, type, signal, providerContext, isDownload}): Promise<Stream[]>
```

Optional flags: `searchFilter`, `blurImage`, `nonStreamableServer[]`,
`nonDownloadableServer[]`.

> The earlier provisional adapter used `getPosts` / `getMeta` with positional
> arguments. **Both the names and the calling convention were wrong.**

### Shapes

* `Post` — `{title, link, image, provider?, aspectRatio?, borderRadius?, tag?, cornerTag?}`
* `Info` — `{title, image, synopsis, type, linkList: Link[], logo?, poster?, imdbId?, tmdbId?, tags?, cast?, rating?, trailerUrl?, …}`
* `Link` — `{title, quality?, episodesLink?, directLinks?: [{title, link, type?, …}]}`
  — a title season/dub grouping; `episodesLink` is followed with
  `GetEpisodeLinks`, `directLinks` are already playable targets.
* `EpisodeLink` — `{title, link, id?, sourceLink?, description?, image?, skip?}`
* `Stream` — `{server, link, type, quality?, tag?, tags?, subtitles?, headers?, skip?}`
  where `subtitles` are `{title, language, type, uri}` and `type` is a MIME
  (`text/vtt`, `application/x-subrip`, `application/ttml+xml`).
* `SkipInterval` — `{title?, from, to}` (intro/recap skip).

### `providerContext` injected into every call

`axios`, `cheerio`, `Crypto`, `getBaseUrl(providerValue)`, `commonHeaders`,
`openWebView(url, options)`, `kvStore` (`get/set/delete/keys/clear`),
`getCookies(url)`.

RPC operations the sandbox may invoke: `fetch`, `getBaseUrl`, `openWebView`,
`getCookies`, `crypto`, `kvGet`, `kvSet`, `kvDelete`, `kvKeys`, `kvClear`.

---

## 3. Nuvio (Mobile **and** TV — identical JS contract)

Sources: `NuvioMobile` `PluginModels.kt`, `PluginManifestParser.kt`,
`runtime/js/JsBindings.kt`, `PluginRepository.kt`;
`NuvioTV` `core/plugin/PluginRuntime.kt`, `domain/model/Plugin.kt`.

Both apps run the same QuickJS bindings and call the same function. Verified
side by side — `NuvioTV/PluginRuntime.kt:144` and
`NuvioMobile/JsBindings.kt:40` are the same call.

### Repository — the URL the user pastes **is** the `manifest.json` URL

```kotlin
val baseUrl = manifestUrl.substringBefore("?").removeSuffix("/manifest.json")
val codeUrl = if (filename.startsWith("http")) filename
              else "$baseUrl/${filename.trimStart('/')}"
```

```json
{ "name": "Repo", "version": "1.0.0", "description": "…", "author": "…",
  "scrapers": [{
    "id": "scraper1", "name": "Scraper", "version": "1.0.0",
    "filename": "scraper1.js", "supportedTypes": ["movie", "tv"],
    "enabled": true, "hasSettings": false, "logo": "…",
    "contentLanguage": ["en"]
  }] }
```

Parser requires non-blank `name`, non-blank `version`, and **at least one
scraper**. Optional per-scraper: `supportedPlatforms`, `disabledPlatforms`,
`formats`, `supportedFormats`, `supportsExternalPlayer`, `limited`.

### The entire plugin API

```js
module.exports.getStreams = async function (tmdbId, mediaType, season, episode) { … }
module.exports.onSettings = async function () { … }   // optional
```

Resolved as `module.exports.getStreams || globalThis.getStreams`. If absent the
host logs an error and returns `[]`. `season`/`episode` are `undefined` for
movies. `mediaType` is `"movie"` or `"tv"`.

Injected globals: `SCRAPER_ID`, `SCRAPER_SETTINGS`, `TMDB_API_KEY`.
Polyfilled: `fetch`, timers, `AbortController`, `atob`/`btoa`, `URL`, `crypto`,
`TextEncoder`, `cheerio`, `require`.

### Result shape (`PluginRuntimeResult`)

```
title, name?, url, quality?, size?, language?, provider?, type?,
seeders?, peers?, infoHash?, headers?, subtitles?
```

`seeders` / `peers` / `infoHash` show this ecosystem is **torrent-first** — Aero
must surface those as torrent links, not pretend they are direct HTTP.

### NuvioTV additionally supports `RepositoryType.EXTERNAL_DEX`

That is CloudStream `.cs3` loading, a separate native path. It is **not** part of
the JS contract and stays behind Aero's CloudStream gate.

---

## 4. What changed in Aero as a result

1. `JsDialect` deleted. Each ecosystem now has a real provider interface:
   `SkyStreamProvider`, `VegaProvider`, `NuvioScraper`.
2. Nuvio's capability set is `{streams}` only. It no longer advertises
   catalogs, search, or details, and the Browse tab will not offer it.
3. SkyStream calls use a callback bridge; Vega calls pass a single object;
   Nuvio calls pass positional arguments.
4. Vega loads six modules and validates `path` against directory traversal.
5. Nuvio results carrying `infoHash` become torrent `StreamLink`s.
6. The Browse tab reproduces SkyStream's dashboard rule (reserved `"Trending"`
   category → hero, everything else → rows) for **every** ecosystem that can
   supply a home feed.

## Re-verification checklist

Upstream moves fast. To re-check, re-read:

* SkyStream — `assets/plugins/plugin.js` and `skystream-tools/DEVELOPER.md`
* Vega — `src/lib/providers/types.ts` and `ExtensionManager.ts` (`requiredFiles`)
* Nuvio — `JsBindings.kt` (`staticCallCode`) and `PluginModels.kt`

If any of those change shape, update the matching provider interface and its
tests — not a shared dialect.
