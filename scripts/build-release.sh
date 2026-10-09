#!/usr/bin/env bash
# Build the customer APKs for distribution.
#
# Usage: scripts/build-release.sh <https api base> [extra flutter build args]
#   e.g. scripts/build-release.sh https://fidelia-api-xxxx.onrender.com --build-name=0.1.0 --build-number=7
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
# Error reports carry this version (lib/core/monitoring/error_reporter.dart),
# so a stack can be matched to the symbols archived for that exact build.
# CI passes --build-name/--build-number, which override pubspec.yaml.
APP_VERSION="$(sed -n 's/^version: *//p' pubspec.yaml)"
BUILD_NAME="${APP_VERSION%%+*}"
BUILD_NUMBER="${APP_VERSION#*+}"
for arg in "$@"; do
  case "$arg" in
    --build-name=*) BUILD_NAME="${arg#*=}" ;;
    --build-number=*) BUILD_NUMBER="${arg#*=}" ;;
  esac
done
APP_VERSION="$BUILD_NAME+$BUILD_NUMBER"

flutter build apk --release \
  --obfuscate --split-debug-info="build/symbols/$APP_VERSION" \
  --dart-define=FIDELIA_API_BASE="$API_BASE" \
  --dart-define=FIDELIA_APP_VERSION="$APP_VERSION" \
  "$@"

echo
echo "Artifacts:"
ls -la build/app/outputs/flutter-apk/*release*.apk
echo
echo "Symbol maps (archive these, do not ship them): build/symbols/$APP_VERSION/"
echo "Read a reported stack with: flutter symbolize -i stack.txt -d build/symbols/$APP_VERSION/app.android-arm.symbols"
