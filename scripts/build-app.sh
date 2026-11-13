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
mkdir -p "$APP/Contents/Frameworks"
XCFRAMEWORK="$(find "$(pwd)/.build/artifacts" -type d -name Sparkle.xcframework -print -quit)"
FRAMEWORK="${MACFALCON_SPARKLE_FRAMEWORK:-$XCFRAMEWORK/macos-arm64_x86_64/Sparkle.framework}"
[[ -d "$FRAMEWORK" ]] || { echo 'Sparkle framework not found in SwiftPM artifacts.' >&2; exit 1; }
ditto "$FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
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
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>SUFeedURL</key><string>https://github.com/7inspire/MacFalcon/releases/latest/download/appcast.xml</string>
<key>SUPublicEDKey</key><string>lT9TwcuuUrk7ko+WaVA8GUCMv33TYrAndjfZyNDrihI=</string>
<key>SUEnableAutomaticChecks</key><true/>
<key>SUAutomaticallyUpdate</key><true/>
<key>SUVerifyUpdateBeforeExtraction</key><true/>
<key>SURequireSignedFeed</key><true/>
</dict></plist>
PLIST
# Local builds are ad-hoc signed. A release must replace this with Developer ID.
codesign --force --sign - --timestamp=none "$APP"
printf 'Built %s\n' "$APP"
