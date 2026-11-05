# Vega providers — PROVISIONAL

**Status:** ⚠️ **NOT VERIFIED.** Phase 0 task.
**Adapter:** `packages/eco_vega` (implemented against a provisional dialect).
**Runtime:** JavaScript in the Aero QuickJS sandbox. All platforms.

> Do not enable this ecosystem by default until the mapping below has been
> confirmed against the current upstream repository. The plan explicitly calls
> for a spec-discovery sprint before adapter code is trusted.

## What we believe to be true

- Providers are JavaScript bundles accompanied by a manifest.
- A repository index lists available providers.
- Providers expose functions roughly equivalent to: home/posts, search,
  metadata, and stream links.

## Provisional dialect

From `VegaAdapter.vegaDialect`:

| Purpose | Assumed name |
|---|---|
| Repository index key | `providers` |
| Home / list | `getPosts(page, category)` |
| Search | `search(query, page)` |
| Details | `getMeta(id)` |
| Streams | `getStream(id, context)` |
| Subtitles | `getSubtitles(id)` |
| Item title field | `title` |
| Item poster field | `image` |
| Item link field | `url` |
| Stream URL field | `url` |
| Stream quality field | `quality` |

## Phase 0 checklist

1. Locate the current official repository and read its provider template.
2. Confirm the exact exported function names and their **argument order**.
3. Confirm the shape returned by each function (array vs `{items: []}`).
4. Determine how episodes are addressed (S/E numbers, an opaque id, or a URL).
5. Identify required host APIs: `fetch`/`axios`, cheerio, crypto, `atob`.
6. Note whether providers rely on `eval`, `Function`, or `setInterval`
   (all denied by the sandbox — a provider using them will need a shim).
7. Record a sample provider as a test fixture in
   `packages/eco_vega/test/fixtures/` and add a conformance test.
8. Update `vegaDialect` and flip the ecosystem to enabled-by-default.

## How to change the mapping

Everything ecosystem-specific lives in one `JsDialect` object. A format change
upstream should be a one-line edit, not a rewrite:

```dart
static const JsDialect vegaDialect = JsDialect(
  fnHome: 'getPosts',   // ← change here
  ...
);
```

If a provider's *shapes* differ rather than just names, override the mapping
helpers in `JsEcosystemAdapterBase` in the Vega subclass.
