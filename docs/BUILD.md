# Build notes

Verified toolchain and the non-obvious problems this build has already solved.
Read this before changing Gradle, the Flutter pin, or a plugin version.

## Verified toolchain

| Component | Version | Notes |
|---|---|---|
| Flutter | `3.47.9` (stable) | Pinned in every workflow via `FLUTTER_VERSION` |
| Dart | `3.13.7` | Ships with the Flutter pin |
| JDK | 17 (Temurin) | AGP 9 requires 17+ |
| Android Gradle Plugin | `9.1.0` | Declared in `settings.gradle.kts` |
| Kotlin | `2.4.0` | |
| Gradle wrapper | `9.3.1` | Wrapper jar is **committed** |
| compileSdk / targetSdk | 36 | |
| minSdk | 24 | Android 7.0 — covers Fire TV Stick 2nd gen and up |
| NDK | `28.2.13676358` | Native code for libmpv / QuickJS |
| CMake | `3.22.1` | |

Additional SDK platforms 34 and 35 are installed because some plugins still
compile against them. All are listed explicitly in `build-apk.yml` so CI cannot
fail on a mid-build licence prompt or download.

## Problems already fixed — do not regress these

### 1. Inconsistent Java/Kotlin JVM targets

Plugins disagree: `flutter_js` compiles Kotlin to **1.8**,
`android_file_picker` compiles Java to **17**, the app uses **11**. Kotlin 2.x
makes any mismatch *within a module* a hard error:

```
Execution failed for task ':flutter_js:compileDebugKotlin'.
> Inconsistent JVM-target compatibility detected for tasks
  'compileDebugJavaWithJavac' (11) and 'compileDebugKotlin' (1.8)
```

Forcing one global target does **not** work — it just moves the failure to the
next plugin (this was tried: a blanket `JVM_11` fixed `flutter_js` and
immediately broke `android_file_picker`).

The fix in `android/build.gradle.kts` derives each module's Kotlin target from
**its own** `JavaCompile` task, read inside a lazy `provider` so it resolves at
execution time:

```kotlin
subprojects {
    tasks.withType(KotlinCompile::class.java).configureEach {
        val kotlinTaskName = name
        compilerOptions.jvmTarget.set(project.provider {
            val javaTask = project.tasks.findByName(
                kotlinTaskName.replace("Kotlin", "JavaWithJavac"),
            ) as? JavaCompile
            JvmTarget.fromTarget(javaTask?.targetCompatibility ?: "11")
        })
    }
}
```

Two constraints worth remembering:

* **Do not wrap this in `afterEvaluate`.** The Flutter template already calls
  `subprojects { project.evaluationDependsOn(":app") }`, so `:app` is evaluated
  by then and `afterEvaluate` throws *"Cannot run Project.afterEvaluate(Action)
  when the project is already evaluated."*
* `kotlin.jvm.target.validation.mode=warning` is set in `gradle.properties` as a
  safety net for future plugins. Everything is dexed by D8 regardless, so a
  mismatch is not a runtime problem on Android.

### 2. `window_manager` is deliberately absent

It pulls Dart native assets (`nativeapi` → `cnativeapi`) whose build hook
requires GTK headers. That breaks plain `flutter test` on a Linux runner:

```
Package 'gtk+-3.0', required by 'virtual:world', not found
Building native assets failed.
```

Desktop is Phase 5. When it lands, add `window_manager` back **together with**
`sudo apt-get install -y libgtk-3-dev libxi-dev` (or equivalent) in the desktop
workflow — not in `ci.yml`.

### 3. `eco_cloudstream` declares no `flutter.plugin` block

Declaring `pluginClass` without a matching native implementation fails the
Android build. The package is pure Dart plus a method-channel stub until the
GPL-3 question in `docs/LEGAL.md` is resolved.

### 4. DateTime columns are stored as TEXT (schema v2)

Drift's default stores `DateTime` as a Unix timestamp in **seconds**. Two writes
in the same second get identical values, so `ORDER BY updated_at DESC` becomes a
tie that SQLite resolves arbitrarily. This was a real bug: watching S01E01 then
S01E02 in quick succession left Continue Watching showing **E01**. Library
ordering by `added_at` had the same flaw.

`packages/aero_data/build.yaml` therefore sets:

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          store_date_time_values_as_text: true
```

ISO-8601 text keeps sub-second precision and sorts lexicographically in
chronological order. **Do not remove this option** — the tests
`same-second writes still order correctly (regression)` and
`v1 -> v2 rewrites Unix-second dates as ISO-8601 text` will fail if you do.

Because the storage type changed, `schemaVersion` is **2** and `onUpgrade`
rewrites existing integer values in place:

```sql
UPDATE watch_history SET updated_at =
  strftime('%Y-%m-%dT%H:%M:%f', updated_at, 'unixepoch', 'localtime')
WHERE typeof(updated_at) = 'integer'
```

Three details that matter:

* `typeof(...) = 'integer'` makes it **idempotent** — safe to re-run.
* `'localtime'` is deliberate. Drift writes `DateTime.toIso8601String()` of a
  *local* `DateTime` (no offset suffix), so converted rows must use the same
  representation or ordering would mix two formats.
* Each table is guarded by a `sqlite_master` existence check so a partially
  created database cannot make the whole upgrade throw.

After changing `build.yaml`, regenerate and **commit** the result:

```bash
cd packages/aero_data
dart run build_runner build --delete-conflicting-outputs
```

### 5. Shimmer honours reduced motion

`Shimmer` reads `MediaQuery.disableAnimationsOf(context)` and does not start its
ticker when animations are disabled. Without this, widget tests fail the
framework's *"A Timer is still pending even after the widget tree was disposed"*
invariant. App widget tests also override providers with **static** values
rather than live Drift streams, which keep their own timers alive.

## Memory

A release build with R8 needs roughly **4 GB** of available memory. GitHub's
`ubuntu-latest` runners have 16 GB, so CI is comfortable.

On a small machine (2 GB RAM), `assembleRelease` will lose its Gradle daemon:

```
Gradle build daemon disappeared unexpectedly (it may have been killed or may have crashed)
```

That is the OOM killer, not a code error. Options:

* Build a debug single-ABI APK instead — no R8, far lighter:
  `flutter build apk --debug --target-platform android-arm64`
* Add swap and cap the heaps (what this repo's `gradle.properties` does):
  `-Xmx2560m -XX:MaxMetaspaceSize=768m`, `org.gradle.parallel=false`,
  `kotlin.daemon.jvmargs=-Xmx1024m`.
* **Never run `flutter test` concurrently with a Gradle build** on a small
  machine; they compete for the same memory and both fail.

## Verified output

A local `--debug --target-platform android-arm64` build succeeds and produces an
APK whose manifest confirms the TV requirements:

```
package: name='app.orbit.media.debug'
application-label:'Aero TV'
launchable-activity: name='app.orbit.media.MainActivity'
leanback-launchable-activity: name='app.orbit.media.MainActivity' banner='res/drawable/tv_banner.png'
uses-feature-not-required: name='android.hardware.touchscreen'
uses-feature-not-required: name='android.software.leanback'
targetSdkVersion:'36'
```

`touchscreen` being **not required** is what makes the app installable on
Android TV; `leanback-launchable-activity` is what puts it on the TV home screen.
The `.debug` suffix is debug-only — release builds use `app.orbit.media`.

Debug APKs are large (~148 MB) because they carry every ABI plus debug symbols.
Release APKs are split per ABI and shrunk, so they are far smaller; CI publishes
the real sizes with each run.

## Local build quick reference

```bash
export JAVA_HOME=/path/to/jdk17
export ANDROID_SDK_ROOT=/path/to/android-sdk
export PATH="$JAVA_HOME/bin:$PATH"

flutter pub get                                    # workspace: one pass
cd apps/aero_app
flutter build apk --release --split-per-abi        # what CI runs
```

`android/local.properties` must contain `flutter.sdk` and `sdk.dir`. It is
gitignored and generated by `flutter` automatically; CI gets its paths from the
runner's setup actions.
