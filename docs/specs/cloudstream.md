# CloudStream (.cs3) — VERIFIED SHAPE, BLOCKED ON LICENSING

**Status:** 🔒 Deliberately **disabled**. Android / Android TV only.
**Adapter:** `packages/eco_cloudstream` (Dart contract + channel client only).
**Sources:**
- https://github.com/recloudstream/cloudstream (GPL-3.0)
- https://recloudstream.github.io/csdocs/
- Repository index format: `plugins.json` on a `builds` branch

## What a .cs3 is

A `.cs3` is a **compiled Kotlin/DEX payload**, not JavaScript. Plugins are
compiled against CloudStream's own Kotlin API (`MainAPI`, `ExtractorApi`, …)
and packaged by the CloudStream Gradle plugin. Repositories publish a
`plugins.json` index alongside the `.cs3` files.

Running one requires:
1. A compatible copy of CloudStream's API classes on the classpath.
2. `DexClassLoader` to load the plugin.
3. An Android `Context`, and sometimes resources, available to the plugin.

## Why this is not implemented

**Licensing.** CloudStream is **GPL-3.0**. Linking its API classes into Aero TV
would very likely require the combined work to be distributed under GPL-3.0.
That is a product-level decision, not an engineering one, and it must be made
before any of that code enters this repository.

**Security.** DEX plugins execute with **full app privileges**. There is no
sandbox comparable to the JS host. A malicious plugin can read app storage,
including any credentials, and make arbitrary network calls.

## Three independent gates

`CloudStreamAdapter.isAvailable` requires all of:

1. `Platform.isAndroid`
2. `--dart-define=AERO_ENABLE_CLOUDSTREAM=true` at build time
3. A native host actually responding on the MethodChannel at runtime

Today all three fail, so the Extensions Manager shows the section greyed out
with an explanation. That is the correct Phase 1 behaviour.

## If you decide to proceed (Phase 3)

1. **Get the licensing question answered in writing.** Decide whether Aero TV
   becomes GPL-3.0, or whether the bridge ships as a separate, separately
   distributed optional module.
2. Add the Kotlin host under `packages/eco_cloudstream/android/`, and
   re-declare the `flutter.plugin` block in that package's pubspec (it is
   intentionally absent today — declaring a missing plugin class breaks the
   Android build).
3. Run the host in a **separate process** (`android:process=":cs_host"`) so a
   crashing plugin cannot take down the UI.
4. Implement hash pinning end-to-end: verify SHA-256 before `DexClassLoader`.
5. Show an explicit, unmissable warning before the first plugin load.
6. Build a compatibility matrix against popular plugins; expect breakage
   wherever a plugin assumes CloudStream's own resources or settings.

## Channel contract

```
isHostPresent() -> bool
loadPlugin({path, sha256}) -> {id, name, version, ...}
invoke({pluginId, method, args}) -> List<Map>
unloadPlugin({pluginId}) -> void
```
