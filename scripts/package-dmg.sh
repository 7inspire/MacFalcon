#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$(pwd)/dist/MacFalcon.app"
VERSION="${MACFALCON_VERSION:-$(tr -d '[:space:]' < VERSION)}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid version' >&2; exit 1; }
[[ -d "$APP" ]] || { echo 'Build dist/MacFalcon.app first.' >&2; exit 1; }
[[ "$(lipo -archs "$APP/Contents/MacOS/MacFalcon")" == "arm64" ]] || { echo 'Release requires an Apple Silicon (arm64) binary.' >&2; exit 1; }
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/macfalcon-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/MacFalcon.app"
ln -s /Applications "$STAGING/Applications"
mkdir -p dist
DMG="$(pwd)/dist/MacFalcon-$VERSION-arm64.dmg"
[[ ! -e "$DMG" ]] || { printf 'Refusing to overwrite %s\n' "$DMG" >&2; exit 1; }
hdiutil create -volname MacFalcon -srcfolder "$STAGING" -ov -format UDZO "$DMG"
printf 'Created %s\n' "$DMG"
