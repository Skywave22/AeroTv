#!/usr/bin/env bash
# Local release build, mirroring what CI does.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/aero_app"

MODE="${1:-split}"
case "$MODE" in
  split)     flutter build apk --release --split-per-abi ;;
  universal) flutter build apk --release ;;
  bundle)    flutter build appbundle --release ;;
  debug)     flutter build apk --debug ;;
  *) echo "Usage: $0 [split|universal|bundle|debug]" >&2; exit 1 ;;
esac

echo ""
echo "Artifacts:"
find build/app/outputs -name "*.apk" -o -name "*.aab" | while read -r f; do
  printf "  %-70s %s\n" "$f" "$(du -h "$f" | cut -f1)"
done
