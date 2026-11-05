# Legal & compliance

> This document is engineering guidance, not legal advice. Get a lawyer before
> you distribute publicly, and specifically before enabling CloudStream.

## Posture

Aero TV is a **neutral player and plugin host**, comparable to Kodi or VLC.

- Ships with **zero** add-ons, repositories, or content links.
- No default sources, no "recommended sources", no curated lists.
- The empty state tells the user to add their own.
- Nothing in the UI, store listing, screenshots, or marketing may name or link
  a specific infringing source.

You are responsible for what you add and for having the right to access it.

## Distribution

| Channel | Assessment |
|---|---|
| **GitHub Releases / own site** | Primary. Recommended for this project. |
| **F-Droid** | Possible, but every dependency must be FOSS and buildable from source. Audit first. |
| **Google Play** | Strict on apps that facilitate piracy. A neutral player can pass, but plugin-host apps get scrutiny. Treat as a later, carefully-reviewed option. |
| **Apple App Store** | Stricter still. Guideline 4.7 governs running third-party code: it must use WebKit/JavaScriptCore, and code distribution must not be the app's main purpose. `flutter_js` already uses JavaScriptCore on iOS for this reason. Treat iOS as a separate compliance project. |

## GPL-3 and CloudStream

CloudStream is **GPL-3.0**. Its `.cs3` plugins are compiled against its Kotlin
API. Shipping a compatible copy of those API classes and loading DEX against
them would very likely make the combined work a derivative subject to GPL-3.0.

**Do not add that code until this is resolved.** Options:

1. License all of Aero TV as GPL-3.0.
2. Ship the bridge as a separate, separately-distributed optional module and
   get advice on whether that is genuinely a separate work.
3. Do not support CloudStream.

The repository is structured so option 3 is the default: the Dart contract
exists, the native host does not, and three independent gates keep it off.

## Other licenses

- **Inter** font — SIL OFL 1.1. License file ships with the fonts.
- **media_kit / libmpv** — media_kit is MIT; **libmpv/FFmpeg builds may be LGPL
  or GPL depending on configuration**. `media_kit_libs_android_video` ships
  prebuilt binaries; verify which build you are distributing and comply with
  its terms (at minimum, provide the offer of source for LGPL components).
- **QuickJS** (via flutter_js) — MIT.
- **Drift, dio, Riverpod** — MIT/BSD.

Run a dependency license audit before any public release.

## Required pages

Before distributing, publish and link from Settings:

- **Terms of Use** — neutral-host framing, user responsibility, no warranty.
- **Privacy Policy** — what is stored locally, what (if anything) leaves the
  device, and that crash reporting is opt-in.
- **DMCA / contact** — a real, monitored address and a takedown procedure.

`BrandConfig` has `termsUrl`, `privacyUrl`, `supportUrl` and `dmcaContact`
fields; they are intentionally empty and must be filled before release.

## Security commitments

- JS plugins: sandboxed, no filesystem, no direct sockets, SSRF-guarded,
  memory- and time-capped, hash-pinned.
- Every plugin network destination is visible in Settings → Log viewer.
- Credentials in the platform keystore/keychain, never in SQLite.
- HTTPS by default; the UI warns on HTTP repositories.
- Crash reporting is **opt-in and off by default**, and must never include
  content titles, URLs, or credentials.
