# Nuvio scrapers — PROVISIONAL

**Status:** ⚠️ **NOT VERIFIED.** Phase 0 task.
**Adapter:** `packages/eco_nuvio`.
**Runtime:** JavaScript in the Aero QuickJS sandbox. All platforms.

## What we believe to be true

- Scrapers are JavaScript, discovered from a repository manifest.
- Titles are keyed by **TMDB id** rather than IMDb. This is why
  `MetadataResolver` exists and why `NuvioAdapter.prefersTmdbIds` is true.

## Provisional dialect

| Purpose | Assumed name |
|---|---|
| Manifest file | `repo.json` |
| Repository index key | `scrapers` |
| Home | `getHome(page, category)` |
| Search | `search(query, page)` |
| Details | `getDetail(id)` |
| Streams | `getSources(id, context)` |
| Results array key | `results` |
| Item link field | `href` |
| Stream quality field | `quality` |

## Phase 0 checklist

1. Find the current Nuvio repository and scraper template.
2. Confirm whether scrapers receive a **TMDB id, an IMDb id, or a full URL**.
3. Confirm how season/episode are passed to `getSources`.
4. Check whether scrapers expect a `Referer` to be preserved across redirects.
5. Verify the repository index shape and whether entries are relative URLs
   (the base adapter resolves relative URLs against the repo URL).
6. Add a fixture + conformance test, then update `nuvioDialect`.

## ID mapping dependency

This ecosystem is the main consumer of the TMDB lookup. Without a user-supplied
TMDB API key, `MetadataResolver` falls back to IMDb + title/year matching, which
will reduce hit rate here. Surface that clearly in the UI (Settings → TMDB API key).
