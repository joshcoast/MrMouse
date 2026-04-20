#!/usr/bin/env bash
#
# build-dmg.sh — build MrMouse.app and wrap it in an unsigned DMG.
#
# This is the "scrappy" distribution path: no Apple Developer account,
# no notarization. The resulting DMG is ad-hoc signed only, so macOS
# Gatekeeper will block the app on first launch — users need to
# right-click the app in /Applications and choose Open → Open.
#
# Usage:
#   ./scripts/build-dmg.sh              # version read from project
#   VERSION=1.2.3 ./scripts/build-dmg.sh
#
# Output:
#   dist/MrMouse-<VERSION>.dmg

set -euo pipefail

# ── config ────────────────────────────────────────────────────────────
PROJECT="MrMouse.xcodeproj"
SCHEME="MrMouse"
APP_NAME="MrMouse"
CONFIGURATION="Release"

# Resolve repo root so the script works no matter where it's called from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BUILD_DIR="$REPO_ROOT/build"
STAGE_DIR="$REPO_ROOT/build/dmg-stage"
DIST_DIR="$REPO_ROOT/dist"

# Version: env override > MARKETING_VERSION from pbxproj.
if [[ -z "${VERSION:-}" ]]; then
    VERSION="$(grep -m1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" \
        | awk -F '= ' '{print $2}' | tr -d ' ;')"
fi
: "${VERSION:?could not determine version}"

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

echo "▶ Building $APP_NAME $VERSION"

# ── preflight ─────────────────────────────────────────────────────────
command -v xcodebuild >/dev/null || {
    echo "✗ xcodebuild not found. Install Xcode (or Xcode Command Line Tools)." >&2
    exit 1
}
command -v create-dmg >/dev/null || {
    echo "✗ create-dmg not found. Install with: brew install create-dmg" >&2
    exit 1
}

# ── clean ─────────────────────────────────────────────────────────────
rm -rf "$BUILD_DIR" "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR"
rm -f "$DMG_PATH"

# ── build ─────────────────────────────────────────────────────────────
# Ad-hoc sign (identity "-") so the app is at least valid Mach-O with
# a signature, even though Gatekeeper won't trust it. No Developer ID,
# no provisioning profile, no team.
echo "▶ xcodebuild (this takes ~30s)"
xcodebuild_args=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -derivedDataPath "$BUILD_DIR"
    CODE_SIGN_IDENTITY="-"
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGNING_ALLOWED=YES
    DEVELOPMENT_TEAM=""
    MARKETING_VERSION="$VERSION"
    build
)

# Pipe through xcbeautify if available for prettier logs. `pipefail`
# (set above) ensures xcodebuild failures still propagate correctly.
if command -v xcbeautify >/dev/null; then
    xcodebuild "${xcodebuild_args[@]}" | xcbeautify --quiet
else
    xcodebuild "${xcodebuild_args[@]}"
fi

APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || { echo "✗ build produced no .app at $APP_PATH" >&2; exit 1; }

# Belt-and-suspenders ad-hoc signing. `xcodebuild` should have done this
# already with CODE_SIGN_IDENTITY="-", but signing the whole bundle
# again (with --deep) ensures all embedded binaries are covered.
echo "▶ ad-hoc signing"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

# ── package ───────────────────────────────────────────────────────────
# Stage just the .app so create-dmg only picks up what we want.
cp -R "$APP_PATH" "$STAGE_DIR/"

echo "▶ create-dmg"
create-dmg \
    --volname "$APP_NAME $VERSION" \
    --window-pos 200 120 \
    --window-size 500 320 \
    --icon-size 96 \
    --icon "$APP_NAME.app" 130 160 \
    --app-drop-link 370 160 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_PATH" \
    "$STAGE_DIR"

echo "✓ wrote $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
