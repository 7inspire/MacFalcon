#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SPARKLE_PRIVATE_KEY:?Set the Sparkle EdDSA private key}"
VERSION="${MACFALCON_VERSION:-$(tr -d '[:space:]' < VERSION)}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid version' >&2; exit 1; }
DMG="$(pwd)/dist/MacFalcon-$VERSION-arm64.dmg"
TOOL="${MACFALCON_APPCAST_TOOL:-$(pwd)/.build/artifacts/mac-monitor/Sparkle/bin/generate_appcast}"
[[ -f "$DMG" && -x "$TOOL" ]] || { echo 'Build the app and DMG first.' >&2; exit 1; }
printf '%s' "$SPARKLE_PRIVATE_KEY" | swift scripts/verify-update-key.swift
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/macfalcon-appcast.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
cp "$DMG" "$STAGING/"
printf '%s' "$SPARKLE_PRIVATE_KEY" | "$TOOL" --ed-key-file - --maximum-deltas 0 --download-url-prefix "https://github.com/7inspire/MacFalcon/releases/download/v$VERSION/" "$STAGING"
cp "$STAGING/appcast.xml" dist/appcast.xml
