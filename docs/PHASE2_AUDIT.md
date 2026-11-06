# Phase 2 audit — plan vs. what is actually built

Audited against the Phase 2 (JS ecosystems) plan on **2026-11-06**, by reading
source rather than the README. Every "missing" was grepped under several
plausible names first, and the two security findings were **executed**, not
inferred.

## Read this first: the plan's contracts are older than our verified ones

The plan says the Vega/Nuvio contracts are "believed" and SkyStream's is
unknown, and proposes isolating that uncertainty in a `JsDialect` per ecosystem.

**That work is already done, and it went further than the plan.** On 2026-11-05
every contract was read from upstream source and recorded in
[VERIFIED_CONTRACTS.md](specs/VERIFIED_CONTRACTS.md). `JsDialect` was **deleted**
because renaming functions cannot express these ecosystems — they differ in
calling convention, module layout and capability surface.

Implementing the plan's §6 literally would regress verified work:

| Plan says | Verified reality | Consequence of following the plan |
|---|---|---|
| Vega `getPosts` / `getMeta`, positional args | `GetHomePosts` / `GetMetaData`, **one object arg** | Every Vega call breaks |
| Vega is "a set of JS modules" | **6 files**: `posts, meta, stream, catalog` required; `episodes, settings` optional | Wrong file set fetched |
| Nuvio returns `{name, title, url, quality…}` | Also `infoHash`, `seeders`, `peers` → **torrent-first** | Torrents mislabelled as direct |
| SkyStream "spec unknown" | **callback-style** `getHome/search/load/loadStreams`, `repo.json`, reserved `"Trending"` → hero | Would re-guess a solved problem |
| `JsDialect` isolates uncertainty | Replaced by one provider interface per ecosystem over a shared `JsSourceManager` | Reintroduces the abstraction we proved inadequate |
| `Capability.details` | Ours is `Capability.meta` | Cosmetic, but a rename would ripple |

Nuvio's `getStreams(tmdbId, mediaType, season, episode)` and stream-only nature
**are** correct in the plan — that matches what we verified.

**Naming:** the plan's "Providers tab" (browse one plugin) is our **Browse** tab.
Our **Providers** tab is the plugin directory. Same features, different labels.

---

## Exit criteria scorecard

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Malicious/buggy plugin cannot freeze UI, crash, or exceed limits | ❌ **Fails** | No isolate; memory cap is a no-op (see G1) |
| 2 | 3 real plugins per ecosystem install and return results | ⚠️ **Unproven** | Contract tests use recorded shapes; no live-plugin run, no `docs/compat.md` |
| 3 | First Stremio result < 3 s while JS plugins still run | ⚠️ **At risk** | Resolver is tiered and progressive, but JS on the UI isolate can block the loop |
| 4 | Browse → details → play, phone + TV remote | ⚠️ **Partial** | Browse works; no LinkGroup chooser, no stream-only test card |
| 5 | Removing a plugin deletes code, cache, logs, config | ⚠️ **Partial** | Code + cache + config yes; no cookie jar or per-plugin log table to clear |
| 6 | No ecosystem names above the adapter layer | ✅ **Likely** | Browse/Providers are capability-driven |
| 7 | ≥70% coverage on `eco_js_runtime` + each dialect | ⚠️ **Unmeasured** | Gate exists only for `aero_core` / `eco_stremio` |

---

## G1 — The sandbox does not sandbox 🔴 (blocks exit criterion 1)

This is the plan's own P2-S0 spike, and **it was never run**. Three of its five
acceptance tests would fail today.

### No worker isolate

`dart:isolate` is imported **nowhere** in the repo. `_evaluateGuarded` does:

```dart
return _withTimeout(() async {
  final res = rt.evaluate(code);   // synchronous FFI, blocks the event loop
  ...
});
```

`.timeout()` cannot fire while the isolate is blocked inside a synchronous
native call. So `while (true) {}` in a plugin **freezes the UI permanently** —
not for 20 s, forever. The plan's §4.2 worker-isolate design is the fix, and it
is not optional.

### The memory cap is a no-op

```dart
if (typeof __setMemoryLimit === 'function') {
  __setMemoryLimit(33554432);
}
```

`flutter_js` does not define `__setMemoryLimit`. The `typeof` guard means this
silently does nothing. `new Array(1e9).fill(1)` is **not** capped. The code
comment says "where the engine supports it" — it does not, and nothing detects
or reports that.

### No CPU interrupt handler

There is no interrupt handler, so there is no way to kill a runaway synchronous
slice. Deadline + isolate gives you cancellation of the *call*, but the runaway
context must be torn down with the isolate.

**Conclusion:** the plan's §3.1 recommendation stands — spike `flutter_js`, and
if it cannot enforce a deadline and a memory cap, go to own FFI over quickjs-ng
behind a `JsEngine` interface. Our evidence says it cannot enforce either today.
At minimum, move execution to a worker isolate so a runaway plugin can be killed
by terminating the isolate.

## G2 — SSRF guard has real holes 🔴

`JsSandboxPolicy.validateUrl` approximates CIDR by taking the first **two**
octets of the network address. Executed against the real Dart policy:

| Host | Result | Should be |
|---|---|---|
| `127.0.0.1` | blocked | ✅ |
| `192.168.1.50` | blocked | ✅ |
| `10.0.0.5` | blocked | ✅ |
| **`10.1.2.3`** | **ALLOWED** | ❌ in `10.0.0.0/8` |
| **`10.255.1.1`** | **ALLOWED** | ❌ in `10.0.0.0/8` |
| **`172.16.0.1`** | **ALLOWED** | ❌ `172.16.0.0/12` not listed at all |
| **`172.31.5.5`** | **ALLOWED** | ❌ same |
| **`fd00::1`** | **ALLOWED** | ❌ IPv6 ULA `fc00::/7` |
| `169.254.169.254` | blocked | ✅ |
| `::1` | blocked | ✅ |

A plugin can reach most of the user's LAN. Also missing: **DNS-rebinding
protection** (resolve the host, check the resolved IP before connecting) — a
public hostname pointing at `192.168.1.1` passes every check.

Fix: real integer CIDR matching for IPv4, IPv6 ULA/link-local checks, and
resolve-then-validate.

---

## Feature gaps

| Gap | Plan § | Notes |
|---|---|---|
| `JsEngine` / `JsContext` abstraction | 4.1 | Absent; `flutter_js` is referenced directly, so the engine choice is not reversible |
| Static scanner (`require` targets, unsupported globals) | 3.3, 5.4 | Absent — no "may not work" badge possible |
| Per-plugin cookie jar | 4.6 | Absent |
| Per-plugin rate limit | 4.6 | Only `maxConcurrentRequests` exists; no requests-per-window cap |
| `IdMap` table + `TitleMatcher` | 5.5, 7.3 | Absent — Vega-style plugins cannot be fed from an IMDb id in the global resolver |
| `PluginLogs` table | 5.5 | Absent; logs go to the shared ring buffer, so per-plugin export/clear is not possible |
| Circuit breaker | 7.5 | Absent — a dead plugin is retried on every play |
| "Modified without version change" flag | 5.4 | Hash pinning exists; this specific approval path does not |
| `LinkGroup` chooser (Vega quality/version) | 6.1, 8.2 | Absent |
| Stream-only "Test this source" card | 6.2, 8.2 | Browse lists Nuvio as non-browsable but offers no way to exercise it |
| Network activity panel | 8.4 | Absent |
| "Run test" diagnostics | 8.4 | Absent — also the main aid for debugging dialects |
| "Wrong match?" override | 7.4 | Absent (depends on TitleMatcher) |
| Source sheet per-plugin status rows | 8.3 | Partial |
| `URLSearchParams` shim | 4.4 | Absent |
| Sandbox/fuzz suite | 9 | Absent — this is what would have caught G1 |
| `docs/compat.md` | 9 | Absent |
| CI grep for bundled repos | 12 | Absent |

## Already built — do not rebuild

QuickJS host with per-plugin contexts and no shared globals; deadline-based job
pump; context pool with LRU eviction; host-brokered HTTP with scheme/size/
concurrency limits; console/timers/fetch/axios/cheerio/crypto/base64/Buffer/
AbortController shims; CommonJS-ish loading; `JsSourceManager` (download, hash
pin, boot, cache, health, teardown); repository browser for all three formats
via the opt-in `RepositorySource` interface; three verified provider interfaces
and adapters; Browse tab with capability-driven filtering and the Trending-hero
rule; plugin directory; `Repositories` table; `MetadataResolver` + TMDB key
setting; tiered progressive resolver; health-aware ranking; stream dedupe and
URL validation; uninstall clearing code/cache/config; TV focus system.

---

## Recommended order

1. **G2 SSRF fix** — small, self-contained, and a real security hole. Do first.
2. **G1 sandbox** — worker isolate + honest limits + the fuzz suite that proves
   it. Largest item, and it gates exit criterion 1. Needs the engine spike.
3. **Sandbox/fuzz suite** — write it alongside G1 so the fix is provable.
4. **TitleMatcher + IdMap + circuit breaker** — makes Vega-style plugins work
   from the Home play flow, which is half the phase's goal.
5. **Diagnostics** (logs table, network activity, run test) — supportability,
   and the tool you need to debug real plugins for criterion 2.
6. **LinkGroup chooser + stream-only test card** — finishes criterion 4.
7. Coverage gate for the JS packages, `docs/compat.md`, CI grep.
