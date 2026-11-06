# Aero TV

[![CI](https://github.com/Skywave22/AeroTv/actions/workflows/ci.yml/badge.svg)](https://github.com/Skywave22/AeroTv/actions/workflows/ci.yml)
[![Build APK](https://github.com/Skywave22/AeroTv/actions/workflows/build-apk.yml/badge.svg)](https://github.com/Skywave22/AeroTv/actions/workflows/build-apk.yml)

**A neutral media player and plugin host. Ships with no content and no sources.**

Aero TV is a Flutter app for Android, Android TV, and (later) desktop. It treats
five plugin ecosystems as separate, first-class citizens — each with its own
manager — behind one calm, cinematic interface.

| Ecosystem | Format | Runs on | Capabilities | Status |
|---|---|---|---|---|
| **Stremio** | HTTP + JSON | All platforms | Catalogs · search · details · streams | ✅ Verified |
| **SkyStream** | JS, callback-style | All platforms | Catalogs · search · details · streams | ✅ Verified |
| **Vega** | JS, six modules | All platforms | Catalogs · search · details · streams | ✅ Verified |
| **Nuvio** | JS, QuickJS | All platforms | **Streams only** (TMDB-keyed) | ✅ Verified |
| **CloudStream** | Kotlin/DEX `.cs3` | Android only | — | 🔒 Disabled pending GPL-3 review |

> **Phase 0 is complete.** Every JS contract was read from upstream source on
> 2026-11-05 and each ecosystem now has its **own** provider interface rather
> than a shared guess. The analysis, the differences that matter, and a
> re-verification checklist are in
> **[docs/specs/VERIFIED_CONTRACTS.md](docs/specs/VERIFIED_CONTRACTS.md)**.
>
> The most consequential finding: **Nuvio plugins only export `getStreams`.**
> They cannot browse or search — Nuvio takes all metadata from TMDB. Aero
> advertises that honestly instead of showing an empty screen.

---

## Navigation

Six tabs, each with one job:

| Tab | Purpose |
|---|---|
| **Home** | Every ecosystem merged into one feed, in your priority order |
| **Browse** | **One plugin's own world** — its categories, its hero, its ordering |
| **Search** | Query across enabled plugins |
| **Library** | Watchlist, favourites, continue watching |
| **Providers** | The plugin directory: what is installed, what it can do |
| **Settings** | Player, UI, backup, and the Extensions manager |

### Adding plugins

The Extensions manager speaks each ecosystem's own distribution format, the way
SkyStream does — paste a repository index, see every plugin it offers, and
install the ones you want:

| Ecosystem | Index | Shape |
|---|---|---|
| SkyStream | `repo.json` | object with a `plugins` array |
| Vega | `manifest.json` | **array** of providers |
| Nuvio | `manifest.json` | **object** with a `scrapers` array |
| Stremio | `manifest.json` | single add-on, installed directly |

Adapters that support this implement the optional `RepositorySource` interface;
the manager detects it with `adapter is RepositorySource` rather than hardcoding
ecosystem names. Repository entries preserve their raw manifest data, hash pins
where the ecosystem provides them, and reject unsafe paths (Vega's `path` is
checked for directory traversal before any file is fetched).

Browse reproduces SkyStream's dashboard rule for every ecosystem that can
supply a home feed: a `"Trending"` category becomes the hero carousel and is
removed from the rows below; if a plugin has no `"Trending"`, its first category
is promoted instead. Plugins that cannot browse (Nuvio) are listed with the
reason rather than silently missing.

---

## What works today (Phase 1)

- **Extensions Manager** — install a Stremio add-on by URL, enable/disable,
  reorder priority, health check, update, remove. One section per ecosystem.
- **Home** — aggregated catalog rows from every enabled add-on, auto-rotating
  hero, Continue Watching.
- **Search** — parallel across all enabled sources, de-duplicated by external ID.
- **Details** — backdrop, palette-tinted theming, seasons/episodes, watchlist
  and favorites.
- **Stream resolver** — parallel fan-out, per-source timeouts, progressive
  results, de-duplication, and a scored source picker.
- **Player** — libmpv via media_kit. Provider headers, external subtitles,
  audio/subtitle track selection, speed, resume, TV remote keys.
- **Library** — watchlist, favorites, history with resume points.
- **Settings** — ranking rules, playback, appearance, TMDB key, backup/restore.
- **Log viewer** — every plugin network destination, in plain sight.
- **Android TV** — leanback launcher, banner, D-pad focus with per-row memory,
  overscan margin, remote key mapping.

**323 automated tests** cover the core models, ranking, resolver, Stremio
protocol, database (including the v1→v2 migration), backup, the JS sandbox
policy, adaptive TV layout and the app's widget tree. `dart analyze
--fatal-infos` is clean across the whole workspace.

## What does not work yet

- Vega / Nuvio / SkyStream need Phase 0 spec verification (see above).
- CloudStream needs a licensing decision and a native Kotlin host.
- Trakt, Chromecast, downloads, PiP, profiles: Phase 4.
- Desktop and iOS: Phases 5–6. The Dart code is platform-clean, but the
  platform folders are not generated yet (the desktop workflow does it).

---

## Quick start

```bash
git clone https://github.com/OWNER/REPO.git
cd REPO
./scripts/setup.sh          # pub get, codegen check, analyze, test

cd apps/aero_app
flutter run                 # phone or emulator
```

### Build an APK locally

```bash
./scripts/build-apk.sh split      # per-ABI APKs (smallest)
./scripts/build-apk.sh universal  # one APK for every device
./scripts/build-apk.sh bundle     # AAB for Play Store
```

Output: `apps/aero_app/build/app/outputs/flutter-apk/`

### Android TV

```bash
# On the TV: Settings → Device Preferences → About → tap Build 7 times
# then Developer options → Network debugging → note the IP
adb connect 192.168.1.50:5555
flutter devices
flutter run -d 192.168.1.50:5555
```

---

## Download an APK

Every push to `main` builds installable APKs. Open the latest
**[Build APK run](https://github.com/Skywave22/AeroTv/actions/workflows/build-apk.yml)**
and download the `aero-tv-apk-…` artifact from the bottom of the page.

| File | Size | Install on |
|---|---|---|
| `app-arm64-v8a-release.apk` | 35.6 MB | **Start here.** Most modern phones, Android TV, Fire TV Stick 4K |
| `app-armeabi-v7a-release.apk` | 32.4 MB | Older 32-bit devices and older Fire TV sticks |
| `app-x86_64-release.apk` | 40.6 MB | Emulators, some Chromebooks |
| `app-release.apk` | 105.6 MB | Universal — works everywhere, larger download |
| `app-release.aab` | 77.6 MB | Play Store upload only, not sideloadable |

Verify against `SHA256SUMS.txt` in the same artifact. Sizes are dominated by
libmpv's native codecs.

> ⚠️ Until signing secrets are added these APKs are **debug-signed** — fine for
> your own testing, not for public distribution. See below.

---

## CI / CD

> Build environment details, verified versions, and the Gradle/JVM pitfalls this
> repo has already solved are documented in **[docs/BUILD.md](docs/BUILD.md)**.


| Workflow | Trigger | Output |
|---|---|---|
| `ci.yml` | push, PR | analyze + all test suites |
| `build-apk.yml` | push to `main`, tags `v*`, manual | split + universal APK, AAB, SHA-256 sums |
| `release-desktop.yml` | manual | Linux / Windows / macOS |

Pushing a tag creates a GitHub Release with the APKs attached:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

### Signed releases (optional but recommended)

Add these repository secrets and CI will sign automatically:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

Without them, builds still succeed but are signed with debug keys — fine for
testing, **not** for distribution.

Generate a keystore:

```bash
keytool -genkey -v -keystore release.keystore -alias release \
  -keyalg RSA -keysize 2048 -validity 10000
```

---

## Repository layout

```
aero_tv/
├─ apps/aero_app/            # Flutter app: screens, routing, Riverpod wiring
│  └─ android/               # TV-ready manifest, banner, signing, ProGuard
├─ packages/
│  ├─ aero_core/             # models, adapter contract, resolver, ranking (pure Dart)
│  ├─ aero_data/             # Drift DB, repositories, settings, backup
│  ├─ aero_ui/               # design system, adaptive shell, TV focus
│  ├─ aero_player/           # media_kit wrapper, controls, tracks
│  ├─ eco_stremio/           # ✅ verified protocol adapter
│  ├─ eco_js_runtime/        # QuickJS sandbox, host API shim, SSRF guard
│  ├─ eco_vega/              # ⚠️ provisional dialect
│  ├─ eco_nuvio/             # ⚠️ provisional dialect
│  ├─ eco_skystream/         # ⚠️ provisional dialect
│  └─ eco_cloudstream/       # 🔒 Dart contract only, no native host
├─ docs/specs/               # one spec doc per ecosystem + verification checklists
└─ scripts/                  # setup, build, push-to-github
```

Dependencies flow one way: `app → packages → aero_core`. `aero_core` is pure
Dart with no Flutter import, so the resolver and ranking are unit-testable
without a device.

See `docs/ARCHITECTURE.md` for the reasoning.

---

## Rebranding

Everything brand-related is in one place:

1. `packages/aero_ui/lib/src/theme/brand_config.dart` — name, tagline, colours, URLs.
2. `apps/aero_app/android/app/src/main/res/values/strings.xml` — launcher label.
3. `apps/aero_app/assets/branding/` + `android/app/src/main/res/mipmap-*/` — icons.
4. `android/app/src/main/res/drawable*/tv_banner.png` — TV banner (320×180).

**The `applicationId` is `app.orbit.media`** — deliberately neutral, because it
cannot be changed once published. Change it *before* your first release if you
want something else. Also check trademarks: "Aero TV" is a working title.

---

## Legal & security posture

Aero TV is a **player**, like Kodi or VLC. It ships with no add-ons, no
repositories and no content links, and it does not promote any source.

- Third-party JS plugins are untrusted: sandboxed, no file access, no direct
  network, SSRF-guarded, timeout- and memory-capped.
- CloudStream DEX plugins would run with full app privileges — which is a major
  reason that bridge is disabled.
- Plugin credentials live in the platform keystore, never in SQLite.
- Crash reporting is opt-in and off by default.

You are responsible for the sources you add and for having the right to access
what you play. See `docs/LEGAL.md`.

## License

The Aero TV source in this repository is MIT (see `LICENSE`), **except** that
integrating CloudStream would impose GPL-3.0 — see `docs/specs/cloudstream.md`.
Bundled Inter font is SIL OFL 1.1 (`apps/aero_app/assets/fonts/OFL.txt`).
