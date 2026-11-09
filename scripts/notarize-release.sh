#!/bin/bash
# Sign and notarize the app, then package, sign, notarize and staple the DMG.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${MACFALCON_SIGN_IDENTITY:?Set MACFALCON_SIGN_IDENTITY to a Developer ID Application identity}"
: "${APPLE_ID:?Set APPLE_ID}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD}"
VERSION="${MACFALCON_VERSION:-$(tr -d '[:space:]' < VERSION)}"
APP="$(pwd)/dist/MacFalcon.app"
DMG="$(pwd)/dist/MacFalcon-$VERSION-arm64.dmg"
[[ -d "$APP" ]] || { echo 'Build the app first.' >&2; exit 1; }
[[ "$(lipo -archs "$APP/Contents/MacOS/MacFalcon")" == "arm64" ]] || { echo 'Release requires an Apple Silicon (arm64) binary.' >&2; exit 1; }
[[ ! -e "$DMG" ]] || { echo "Release DMG already exists; remove it explicitly before retrying." >&2; exit 1; }
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/macfalcon-notary.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
notarize() {
  local file="$1" output="$TEMP/notary.json"
  xcrun notarytool submit "$file" --apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait --output-format json > "$output"
  python3 - "$output" <<'PY'
import json, sys
with open(sys.argv[1]) as f: result = json.load(f)
print('Notarization:', result.get('status', 'unknown'), '| ID:', result.get('id', 'unknown'))
if result.get('status') != 'Accepted': sys.exit(1)
PY
}
codesign --force --options runtime --timestamp --sign "$MACFALCON_SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --keepParent "$APP" "$TEMP/MacFalcon.zip"
notarize "$TEMP/MacFalcon.zip"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
MACFALCON_VERSION="$VERSION" ./scripts/package-dmg.sh
codesign --force --timestamp --sign "$MACFALCON_SIGN_IDENTITY" "$DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
codesign --verify --verbose=2 "$DMG"
(cd dist && shasum -a 256 "$(basename "$DMG")" > SHA256SUMS.txt)
printf 'Signed and notarized: %s\n' "$DMG"
