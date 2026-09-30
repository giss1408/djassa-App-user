#!/usr/bin/env bash
# Build the customer APKs for distribution.
#
# Usage: scripts/build-release.sh <https api base> [extra flutter build args]
#   e.g. scripts/build-release.sh https://djassa-api-xxxx.onrender.com --build-name=0.1.0 --build-number=7
#
# Produces one APK per ARM ABI plus a universal APK, with Dart obfuscation on
# and the symbol map kept in build/symbols/ (archive it, never ship it).
set -euo pipefail

API_BASE="${1:-}"
if [ -z "$API_BASE" ]; then
  echo "usage: $0 <https api base url> [extra flutter build args]" >&2
  exit 2
fi
shift
case "$API_BASE" in
  https://*) ;;
  *) echo "error: API base must be https, got: $API_BASE" >&2; exit 2 ;;
esac

cd "$(dirname "$0")/.."

if [ ! -f android/key.properties ]; then
  echo "warning: android/key.properties is missing; the APKs will be UNSIGNED." >&2
  echo "         See android/key.properties.example. Do not distribute unsigned builds." >&2
fi

# The splits{} block in android/app/build.gradle already emits one APK per ABI
# plus the universal one; do not also pass --split-per-abi.
flutter build apk --release \
  --obfuscate --split-debug-info=build/symbols \
  --dart-define=DJASSA_API_BASE="$API_BASE" \
  "$@"

echo
echo "Artifacts:"
ls -la build/app/outputs/flutter-apk/*release*.apk
echo
echo "Symbol maps (archive these, do not ship them): build/symbols/"
