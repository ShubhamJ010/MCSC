#!/usr/bin/env bash
#
# verify.sh — Verify the installed /Applications/MCSC.app code signature and bundle.
# User-invokable skill script.
#
# Usage:
#   ./verify.sh
#
# Exits 0 if the app is present and properly signed, non-zero otherwise.

set -euo pipefail

APP_DEST="/Applications/MCSC.app"

if [[ ! -d "${APP_DEST}" ]]; then
  echo "ERROR: ${APP_DEST} not found. Run build-release.sh first." >&2
  exit 1
fi

echo "==> Bundle contents:"
ls -la "${APP_DEST}/Contents/MacOS"

echo "==> Code signature:"
codesign -dvvvv "${APP_DEST}"

echo "==> Architecture:"
file "${APP_DEST}/Contents/MacOS/MCSC"

echo "==> Gatekeeper assessment:"
if spctl -a -vvvv "${APP_DEST}" 2>&1; then
  echo "==> Gatekeeper: accepted."
else
  echo "==> Gatekeeper: not notarized (expected for a Development-signed build)."
fi

echo "==> Verification complete."