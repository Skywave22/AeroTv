# SkyStream plugins — PROVISIONAL

**Status:** ⚠️ **NOT VERIFIED.** Phase 0 task.
**Adapter:** `packages/eco_skystream`.
**Runtime:** JavaScript in the Aero QuickJS sandbox. All platforms.

## What we believe to be true

- Plugins are JavaScript with a repository index.
- The browsing model is **one plugin at a time**, using the plugin's own home,
  categories and search — this is what the Providers tab is designed around.

## Provisional dialect

| Purpose | Assumed name |
|---|---|
| Manifest file | `plugins.json` |
| Repository index key | `plugins` |
| Home | `loadHome(page, category)` |
| Search | `search(query, page)` |
| Details | `load(id)` |
| Streams | `loadLinks(id, context)` |
| Item title field | `name` |
| Item link field | `url` |
| Stream quality field | `label` |

## Phase 0 checklist

1. Locate the current SkyStream repository and plugin template.
2. Confirm the home/category contract — does `loadHome` return categories,
   items, or both?
3. Confirm the stream-link shape (some ecosystems nest `{links: [...]}` under
   a server list; the base adapter unwraps `links`, `streams` and `data`).
4. Check for host APIs beyond fetch/cheerio (e.g. a crypto or unpacker helper).
5. Add a fixture + conformance test, then update `skyStreamDialect`.
