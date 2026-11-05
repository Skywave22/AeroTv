# Stremio add-on protocol — VERIFIED

**Status:** ✅ Verified against the official SDK docs. Implemented in `packages/eco_stremio`.
**Difficulty:** Easy. Pure Dart + HTTP, runs on every platform.
**Sources:**
- Protocol: https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/protocol.md
- Stream object: https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/api/responses/stream.md

## Transport

Everything is HTTP GET returning JSON. A user installs by supplying a manifest URL.

| Resource | URL | Response |
|---|---|---|
| Manifest | `/manifest.json` | manifest object |
| Catalog | `/catalog/{type}/{id}.json` | `{ metas: [...] }` |
| Catalog + extras | `/catalog/{type}/{id}/{extra}.json` | `{ metas: [...] }` |
| Meta | `/meta/{type}/{id}.json` | `{ meta: {...} }` |
| Stream | `/stream/{type}/{videoId}.json` | `{ streams: [...] }` |
| Subtitles | `/subtitles/{type}/{videoId}/{extra}.json` | `{ subtitles: [...] }` |

**Extras** are `key=value` pairs joined with `&`, forming a *single* path segment:

```
/catalog/movie/top/genre=Action&skip=100.json
/catalog/movie/top/search=the%20matrix.json
```

**Configurable add-ons** put user config in a path segment *before* the resource:

```
https://host/eyJkZWJyaWQiOiIxMjMifQ/manifest.json
https://host/eyJkZWJyaWQiOiIxMjMifQ/stream/movie/tt0111161.json
```

`StremioApi.baseUrlOf()` preserves that segment. This is the single most common
bug in third-party clients — do not strip it.

## Manifest

```jsonc
{
  "id": "org.example.addon",
  "version": "1.0.0",
  "name": "Example",
  "types": ["movie", "series"],
  "idPrefixes": ["tt"],
  "resources": [
    "catalog",                                    // string form
    { "name": "stream", "types": ["movie"], "idPrefixes": ["tt"] }  // object form
  ],
  "catalogs": [
    { "type": "movie", "id": "top", "name": "Popular",
      "extra": [ { "name": "search" }, { "name": "genre", "options": ["Action"] } ] }
  ],
  "behaviorHints": { "configurable": true, "configurationRequired": false, "adult": false }
}
```

Implementation notes:
- `resources` entries may be **strings or objects**. Both are handled.
- Some add-ons use a singular `type` instead of `types`. Handled.
- A catalog is searchable **iff** its `extra` contains an entry named `search`.
- `configurationRequired: true` → refuse install and tell the user to configure
  on the add-on's own page, then install the generated URL.

## IDs

- Movies: IMDb id, e.g. `tt0111161`.
- Series episodes: `{imdb}:{season}:{episode}`, e.g. `tt0944947:1:2`.
- The `stream` resource is declared against type `series`, but the id is the
  composite episode id. Match `idPrefixes` against the **base** id.

Colons must NOT be percent-encoded in the path. `StremioApi.encodeId()` handles this.

## Stream object

One of `url`, `ytId`, `infoHash`, `externalUrl`, or archive/usenet fields must be present.

```jsonc
{
  "url": "https://cdn/v.mkv",
  "name": "1080p",                 // usually the quality line
  "description": "WEB-DL x264",    // `title` is the DEPRECATED name for this
  "behaviorHints": {
    "notWebReady": true,
    "bingeGroup": "addon-1080",
    "videoSize": 1610612736,
    "filename": "Movie.2010.1080p.mkv",
    "proxyHeaders": { "request": { "Referer": "https://ref.example", "User-Agent": "X" } }
  },
  "subtitles": [ { "id": "s1", "url": "https://x/en.srt", "lang": "en" } ]
}
```

**Critical for playback:** `behaviorHints.proxyHeaders.request` contains headers
the stream URL *requires*. Without them most providers return 403. These are
passed to libmpv via `http-header-fields` and `referrer`.

**Torrents:** a stream with only `infoHash` is not directly playable. Aero TV
labels these and does not attempt to play them. A debrid add-on resolves the
hash server-side and returns a normal `url`; those are detected and badged.

## Error handling

- 404 is a normal "no results" answer → treated as empty, not an error.
- Add-ons often serve JSON with a `text/plain` content type → decode defensively.
- Per-source timeout of 12 s in the resolver; a slow add-on never blocks playback.

## Test coverage

`packages/eco_stremio/test/stremio_test.dart` — 29 tests covering URL building
(including config segments and colon preservation), manifest parsing (both
resource forms), meta/episode parsing, `proxyHeaders`, HLS/DASH detection,
torrent labelling, size/language/codec inference and install validation.
