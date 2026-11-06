# Phase 1 audit — plan vs. what is actually built

> **Update 2026-11-06:** G1, G2 and G3 are now **fixed** — see
> [Progress](#progress) at the bottom. The findings below are preserved as the
> original record.

Audited against the Phase 1 (Android + Android TV MVP) plan on **2026-11-06**.
Method: read the source, not the README. Every "missing" below was grepped for
under several plausible names before being called missing.

## Context: the repo has overshot Phase 1 in one direction

Phase 1 scopes **Stremio only**, with the other ecosystems deferred to Phase 2.
The repo already ships five ecosystems, a Browse tab, and per-ecosystem plugin
managers (188 tests, CI + APK green). That work is *ahead* of the plan and
should not be undone to match it.

But several **Stremio-path fundamentals the plan treats as exit criteria are not
done**. Overshooting on breadth left gaps in depth.

---

## Exit criteria scorecard

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Cold start → usable Home < 2.5 s | ❌ **Fails** | No disk cache for catalogs; Home refetches everything on every launch (see G1) |
| 2 | Install/browse/play on real TV, remote only | ⚠️ **Unverified** | Focus system exists; no scripted D-pad test, no device run |
| 3 | First stream in sheet < 3 s, slow add-ons non-blocking | ✅ **Likely** | `StreamResolver` 12 s/source, 25 s overall, concurrency 6, progressive sink |
| 4 | Broken/slow add-on never crashes or blocks UI | ✅ **Likely** | Per-source try/catch + timeouts in `homeRowsProvider` and resolver |
| 5 | Resume across restarts | ✅ **Passes** | Drift `WatchHistory`, `resumePoint()`, position saved periodically |
| 6 | Zero analyzer warnings; ≥70% coverage in `aero_core` + `eco_stremio` | ⚠️ **Half** | Analyzer clean across 11 packages. Coverage **never measured** |

---

## Gaps that block exit criteria

### G1 — The cache layer exists but is not wired up 🔴

`CacheRepository` is fully implemented (`get`/`put`/`remember`/`prune`) and the
`MediaCache` table exists. **Almost nothing calls it.** The only `ttl:` call site
in the app stores JS plugin code for 3650 days.

Consequences:

* `homeRowsProvider` awaits up to 8 sources × 3 catalogs, each with a 12 s
  timeout, on **every** cold start. There is no cached first frame.
* The Stremio manifest cache is an in-memory `Map` (`stremio_adapter.dart:42`),
  so it dies with the process.
* Plan §4.5 TTLs are entirely absent: manifest 24 h, catalogs 15 min
  stale-while-revalidate, meta 6 h, streams 2 min in-memory.
* Plan §8 budget "Home first frame under 1 s from cache" cannot be met.

This is the single highest-value fix in the list. It needs a `swr()` method
(return stale immediately, revalidate behind) and TTL constants applied at the
adapter boundary.

### G2 — Home does not filter home-eligible catalogs 🔴

Plan §4.3 defines `isHomeEligible` = no required extras other than `skip`.
`CatalogDescriptor` has **no such field**, and `_catalog()` in
`stremio_manifest.dart` reads only `search` and `genre` out of `extra` — it never
records `isRequired`.

`homeRowsProvider` then does `catalogs.take(3)` blindly. A catalog that *requires*
a search term or a genre can occupy a Home row, where it will return an error or
an empty list. Correct behaviour is to skip it and take the next eligible one.

### G3 — No recorded fixtures for the Stremio contract 🟠

Plan §9 calls for `eco_stremio/test/fixtures/` with manifest variants, catalogs
with and without `extra`, streams with `behaviorHints`, and malformed responses.
**The directory does not exist.** The 29 `eco_stremio` tests use inline maps.

The JS ecosystems got proper contract tests last phase; Stremio — the one
ecosystem Phase 1 actually ships — did not.

---

## Gaps against the plan, not blocking exit criteria

| Gap | Plan § | Notes |
|---|---|---|
| **No `dev`/`alpha`/`prod` flavors** | 3.3 | Only a `debug` suffix. `applicationId` is correctly `app.orbit.media` |
| **Resume is silent, not prompted** | 6.4 | Auto-resumes; plan wants "Resume from 34:12 / Start over" |
| **No "add from phone" LAN server** | 7.3 | QR flow shows a code but there is no `shelf` server or one-time token. Typing a URL with a remote is still required |
| **No voice search** | 5.3 | `speech_to_text` absent |
| **No `app_links` / `stremio://` intent** | 3.2 | Manifest registers `aerotv://` only; `stremio://` is normalised in code but not intercepted from the OS |
| **No credential masking in logs** | 8 | Add-on URLs often embed tokens. `AeroLog` has no redaction |
| **No licenses page** | 8 | `showLicensePage` never called |
| **No `integration_test`** | 9 | No install → Home → Details → sheet → player walkthrough |
| **No golden tests** | 9 | Cards, hero, sheet, focus ring at phone + TV sizes |
| **No scripted D-pad tests** | 9 | `sendKeyEvent` unused; criterion 2 is unproven |
| **No opt-in Sentry** | 8 | Off-by-default crash reporting absent |
| **Coverage unmeasured** | 1.6 | Needs `flutter test --coverage` + `lcov` per package |

---

## Already done — do not rebuild

Verified present and working: `BrandConfig`, `FormFactor` + `aero/device`
MethodChannel, `StatefulShellRoute`, adaptive shell, Drift schema (9 tables,
v2 migrations), `StreamResolver` (progressive/parallel), ranking with prefs,
source sheet, media_kit player with subtitles/audio/speed/aspect, subtitle delay,
wakelock, phone gestures, `bingeGroup` next-episode, **playback error recovery**
("Try another source"), `TvFocus` + `RowFocusMemory`, `PopScope`, media keys,
`proxyHeaders`, `infoHash` handling, `supports()` resource matcher, 401/403
retry, dedupe, row caps, health tracking, backup/restore, log viewer,
no-content disclaimer.

Two deliberate deviations from the plan, both justified and worth keeping:

* **No `freezed`/`json_annotation`.** Hand-written models. Codegen for the whole
  model layer OOMs the 1.9 GiB build box; only Drift uses codegen.
* **No `mobile_scanner`.** Dropped for native-build reasons; `qr_flutter`
  covers display. Re-add only alongside the G-list LAN server work.

---

## Recommended order

1. **G1 + G2 together** — they are the same code path, and they are what stands
   between the app and exit criteria 1. Cache TTLs + SWR + home-eligible filter.
2. **G3 fixtures** — cheap, and locks the Stremio contract the way the JS
   contracts are now locked.
3. **D-pad tests + coverage measurement** — converts criteria 2 and 6 from
   "unverified" into pass/fail.
4. **Add-from-phone LAN server** — the largest remaining TV usability win.
5. Flavors, resume prompt, masking, licenses, deep links — polish.


---

## Progress

### G1 — cache wired ✅

* `JsonCache` interface added to `aero_core` so `eco_*` packages can cache
  without importing Drift. `CacheRepository` implements it.
* `CacheRepository.get()` no longer **deletes** expired rows — that made
  stale-while-revalidate impossible. `read()` returns them marked `isStale`;
  `prune()` removes them in bulk.
* TTLs from plan §4.5 applied at the adapter boundary: manifest 24 h,
  catalog 15 min (SWR), meta 6 h. Streams stay uncached on disk.
* Catalog reads serve stale instantly and refresh behind a de-duplicating
  guard, so concurrent stale reads cause one fetch, not a stampede.
* Manifest and meta fall back to stale data when the add-on is unreachable, so
  offline browsing works instead of showing an empty app.

### G2 — Home eligibility ✅

`requiredExtras` is parsed from the manifest's `extra[].isRequired` and carried
on both `CatalogDescriptor` and `CatalogRow`. `isHomeEligible` exempts `skip` and
`limit` (pagination, not filters). Home now filters on it before `take(3)`.

### G3 — fixtures, D-pad, coverage ✅

* `packages/eco_stremio/test/fixtures/` — 9 recorded responses: Cinemeta-style
  string resources, object resources with per-resource scopes,
  `configurationRequired`, catalog pages, series metadata with `videos`,
  streams with `behaviorHints`, unplayable torrent/yt/external streams, and an
  HTML error page. 22 contract tests read them.
* `packages/aero_ui/test/tv_focus_test.dart` — 13 remote-only tests: Select /
  Enter / gamepad-A activation, D-pad Left/Right/Down traversal, no wrap at the
  last item, and row focus memory including a clamped index after a row shrinks.
* Coverage measured and gated in CI at ≥70%: **aero_core 77.4%**,
  **eco_stremio 79.0%**.

### Two real bugs the new tests exposed

1. **`StremioApi._asMap` did not decode String bodies.** It claimed to "decode
   defensively" but only handled `Map`. Dio only auto-decodes JSON when the
   content type says JSON, and many add-ons reply `text/plain` — those manifests
   were rejected as malformed. Now decodes String bodies and rejects HTML.
2. **Manifest catalog round-trip was lossy.** `toJson()` emitted Aero's shape
   while `fromJson()` expected the Stremio wire shape, so a cached manifest lost
   `searchable`, `genres` and `requiredExtras` on every launch after the first.
   The parser now accepts both shapes. This would have silently broken Home
   eligibility and search once G1 landed.
