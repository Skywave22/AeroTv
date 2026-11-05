#!/usr/bin/env bash
# One-time local setup for contributors.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "→ Checking Flutter…"
command -v flutter >/dev/null || {
  echo "Flutter is not installed. Get it from https://docs.flutter.dev/get-started/install" >&2
  exit 1
}
flutter --version

echo "→ Resolving workspace dependencies…"
flutter pub get

echo "→ Verifying generated Drift code…"
(cd packages/aero_data && dart run build_runner build)

echo "→ Analyzing…"
dart analyze --fatal-infos

echo "→ Running tests…"
(cd packages/aero_core && dart test)
(cd packages/eco_stremio && dart test)
(cd packages/aero_data && flutter test)
(cd packages/eco_js_runtime && flutter test)

cat <<'DONE'

✓ Setup complete.

Next steps:
  cd apps/aero_app
  flutter run                       # phone / emulator
  flutter build apk --release --split-per-abi

Android TV: enable Developer Options on the device, then
  adb connect <device-ip>:5555
  flutter run -d <device-id>
DONE
