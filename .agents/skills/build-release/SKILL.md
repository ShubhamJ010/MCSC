---
name: build-release
description: Build a signed Release archive of the MCSC macOS app with the user's Apple Development identity, install it to /Applications, and launch it for testing. User-invoked for local release testing.
---

# Build & Install MCSC Release

Build a code-signed Release archive of the MCSC app and install it into `/Applications` for local testing.

## When to use
- The user wants to test a release build of MCSC on their Mac.
- The user says "build release", "make a release app", "install release build", or "archive and sign".

## Prerequisites
- Xcode must be installed (`xcodebuild` available).
- A valid Apple Development signing identity must exist. Find it with:
  ```bash
  security find-identity -v -p basic
  ```
- The archive uses these project files (do not change them unless intentionally):
  - Scheme: `MCSC`
  - Configuration: `Release`
  - Entitlements: `MCSC.entitlements` (app-sandbox = false)
  - Bundle ID: read from the project's `Info.plist` (`CFBundleIdentifier`) — do not hardcode.

## Scripts (preferred, one-shot)

This skill ships with ready-to-run scripts in `scripts/`. Use them instead of typing the commands manually:

- **`scripts/build-release.sh`** — does everything in one go (resolve identity → archive → install → verify → launch).
  ```bash
  # from the skill's scripts dir, or anywhere
  bash .agents/skills/build-release/scripts/build-release.sh
  # or with an explicit identity:
  bash .agents/skills/build-release/scripts/build-release.sh "Apple Development: you@icloud.com (XXXX)"
  ```
  If `/Applications` is not writable by the current user, the install step will prompt for `sudo`.

- **`scripts/verify.sh`** — re-checks the installed app's signature and architecture:
  ```bash
  bash .agents/skills/build-release/scripts/verify.sh
  ```

Both scripts are marked executable. The `build-release.sh` auto-detects the first valid `Apple Development` identity when none is passed.

## Manual Steps (if running commands by hand)

1. **Resolve the signing identity** (if not already known):
   ```bash
   security find-identity -v -p basic
   ```
   Capture the identity string from the output, e.g. `Apple Development: your@email.com (TEAMID)` — the script auto-detects it for you.

2. **Archive the app** (Release, universal arm64+x86_64, signed):
   ```bash
   xcodebuild archive \
     -scheme MCSC \
     -configuration Release \
     -archivePath /tmp/MCSC.xcarchive \
     CODE_SIGN_IDENTITY="<Identity from step 1>"
   ```
   Expect `** ARCHIVE SUCCEEDED **` and a `CodeSign` step using the chosen identity with the hardened runtime (`-o runtime`).

3. **Install into /Applications** (preserving the signature):
   ```bash
   ditto /tmp/MCSC.xcarchive/Products/Applications/MCSC.app /Applications/MCSC.app
   ```
   Use `ditto` (not `cp`) so the code signature stays valid.

4. **Verify** the installed app:
   ```bash
   codesign -dvvvv /Applications/MCSC.app
   file /Applications/MCSC.app/Contents/MacOS/MCSC
   ```

5. **Launch for testing**:
   ```bash
   open /Applications/MCSC.app
   ```

## Notes
- This produces a **Development**-signed build. It runs on the developer's Mac but is NOT notarized for distribution to others.
- For distribution you would need a macOS **Distribution** certificate + Apple Developer Program membership, then Notarization via Xcode Organizer.
- The app is an `LSUIElement` (status-bar / agent) app — it may not show a Dock icon; check the menu bar / Accessibility prompt.
- First launch triggers a macOS Accessibility permission prompt (see `NSAccessibilityUsageDescription` in Info.plist). Grant it in System Settings → Privacy & Security → Accessibility.