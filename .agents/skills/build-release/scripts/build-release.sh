#!/usr/bin/env bash
#
# build-release.sh — Build, sign, install, and launch the MCSC release app.
# User-invokable skill script. Run from the repo root or anywhere.
#
# Usage:
#   ./build-release.sh                 # auto-detects the first Apple Development identity
#   ./build-release.sh "Apple Development: you@icloud.com (XXXX)"   # explicit identity
#
# What it does:
#   0. Uninstalls any existing /Applications/MCSC.app and resets its
#      Accessibility (TCC) permission so the fresh build starts clean.
#   1. Resolves an Apple Development signing identity (auto or passed).
#   2. xcodebuild archive (Release, universal arm64+x86_64, hardened runtime).
#   3. ditto the signed .app into /Applications/MCSC.app.
#   4. Verifies the code signature.
#   5. Launches the installed app for testing.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
ARCHIVE_PATH="/tmp/MCSC.xcarchive"
APP_DEST="/Applications/MCSC.app"
SCHEME="MCSC"
CONFIG="Release"

# Bundle ID is read from Info.plist (do not hardcode).
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${REPO_ROOT}/Info.plist")"

echo "==> Repo root: ${REPO_ROOT}"
echo "==> Bundle ID: ${BUNDLE_ID}"

# --- 0. Uninstall existing install & reset Accessibility TCC ----------------
echo "==> Step 0: Uninstalling existing install and resetting Accessibility permission..."

# Quit the running app (if any) so the bundle can be removed.
echo "    -> Quitting any running MCSC process..."
osascript -e 'tell application "MCSC" to quit' 2>/dev/null || true
# Belt-and-suspenders: kill by bundle id if it is still running.
pkill -f "/Applications/MCSC.app/Contents/MacOS/MCSC" 2>/dev/null || true
sleep 1

# Remove the installed app bundle.
if [[ -d "${APP_DEST}" ]]; then
  echo "    -> Removing ${APP_DEST}..."
  if [[ -w "$(dirname "${APP_DEST}")" ]]; then
    rm -rf "${APP_DEST}"
  else
    sudo rm -rf "${APP_DEST}"
  fi
fi

# Reset the Accessibility (TCC) permission grant for this bundle id so the
# freshly built binary is treated as a new, untrusted app and re-prompts.
echo "    -> Resetting Accessibility (TCC) permission for ${BUNDLE_ID}..."
tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || \
  sudo tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || \
  echo "    (tccutil reset skipped or failed — may require manual reset in System Settings)"
echo "    -> Clean-up done."

# --- 1. Resolve signing identity -------------------------------------------
IDENTITY="${1:-}"
if [[ -z "${IDENTITY}" ]]; then
  echo "==> No identity passed, detecting first valid Apple Development identity..."
  IDENTITY="$(security find-identity -v -p basic | grep -m1 "Apple Development" | sed -E 's/.*"([^"]+)".*/\1/')"
  if [[ -z "${IDENTITY}" ]]; then
    echo "ERROR: No Apple Development signing identity found. Run 'security find-identity -v -p basic'." >&2
    exit 1
  fi
fi
echo "==> Using signing identity: ${IDENTITY}"

# --- 2. Archive -------------------------------------------------------------
echo "==> Archiving (scheme=${SCHEME}, config=${CONFIG})..."
xcodebuild archive \
  -scheme "${SCHEME}" \
  -configuration "${CONFIG}" \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGN_IDENTITY="${IDENTITY}" \
  CODE_SIGN_STYLE=Manual

# --- 3. Install -------------------------------------------------------------
SRC_APP="${ARCHIVE_PATH}/Products/Applications/MCSC.app"
if [[ ! -d "${SRC_APP}" ]]; then
  echo "ERROR: Built app not found at ${SRC_APP}" >&2
  exit 1
fi

echo "==> Installing to ${APP_DEST} (ditto preserves signature)..."
sudo -n true 2>/dev/null || true   # prime sudo if needed; fall back to user-permitted prompt
if [[ -w "$(dirname "${APP_DEST}")" ]]; then
  rm -rf "${APP_DEST}"
  ditto "${SRC_APP}" "${APP_DEST}"
else
  sudo ditto "${SRC_APP}" "${APP_DEST}"
fi

# --- 4. Verify --------------------------------------------------------------
echo "==> Verifying signature..."
codesign -dvvvv "${APP_DEST}"
file "${APP_DEST}/Contents/MacOS/MCSC"

# --- 5. Launch --------------------------------------------------------------
echo "==> Launching ${APP_DEST}..."
open "${APP_DEST}"

echo "==> Done. MCSC release is installed at ${APP_DEST}."