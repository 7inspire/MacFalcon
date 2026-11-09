#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${MACFALCON_VERSION:-$(tr -d '[:space:]' < VERSION)}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Invalid version: expected MAJOR.MINOR.PATCH\n' >&2
  exit 1
fi
ARGS=(-c release --arch arm64)
swift build "${ARGS[@]}" "$@"
BIN_DIR="$(swift build "${ARGS[@]}" --show-bin-path "$@")"
APP="$(pwd)/dist/MacFalcon.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$BIN_DIR/MacMonitor" "$APP/Contents/MacOS/MacFalcon"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MacFalcon</string>
<key>CFBundleIdentifier</key><string>io.github.7inspire.MacFalcon</string>
<key>CFBundleName</key><string>MacFalcon</string>
<key>CFBundleDisplayName</key><string>MacFalcon</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Local builds are ad-hoc signed. A release must replace this with Developer ID.
codesign --force --sign - --timestamp=none "$APP"
printf 'Built %s\n' "$APP"
