#!/usr/bin/env bash
# Run the customer app on a USB-connected Android device against a backend on
# this machine.
#
# Usage: scripts/run-device.sh [backend port] [extra flutter run args...]
#
# `adb reverse` makes the phone's own localhost:PORT tunnel back to this
# machine over USB: no shared Wi-Fi needed, traffic never leaves the cable.
# (10.0.2.2 is emulator-only and does NOT work on a physical device.)
#
# The sign-in form is prefilled with the backend's demo customer
# (app/api/auth.py). Override with DJASSA_DEV_USERNAME / DJASSA_DEV_PASSWORD.
set -euo pipefail

PORT="${1:-8002}"
shift || true
cd "$(dirname "$0")/.."

if ! adb get-state >/dev/null 2>&1; then
  echo "error: no device over adb. Enable USB debugging and check 'adb devices'." >&2
  exit 1
fi

echo "Tunnelling device localhost:$PORT -> this machine's $PORT"
adb reverse "tcp:$PORT" "tcp:$PORT"

# Cleartext to localhost is permitted in debug builds only, and only for
# loopback (see android/app/src/debug/res/xml/network_security_config.xml).
exec flutter run \
  --dart-define=DJASSA_API_BASE="http://localhost:$PORT" \
  --dart-define=DJASSA_DEV_USERNAME="${DJASSA_DEV_USERNAME:-client}" \
  --dart-define=DJASSA_DEV_PASSWORD="${DJASSA_DEV_PASSWORD:-client123}" \
  "$@"
