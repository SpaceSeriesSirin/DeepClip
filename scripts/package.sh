#!/bin/bash
#
# Builds CacheMind in release mode and assembles a runnable .app bundle
# (SPEC Phase 7). Produces ./CacheMind.app in the project root.
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="CacheMind.app"
APP_NAME="CacheMind"

echo "==> Building release binary (arm64)…"
swift build -c release --arch arm64

BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
BIN="$BIN_DIR/$APP_NAME"
if [[ ! -f "$BIN" ]]; then
    echo "error: built binary not found at $BIN" >&2
    exit 1
fi

echo "==> Assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Generating AppIcon…"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
swift "scripts/generate_icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Ad-hoc code signing…"
codesign --force --deep --sign - "$APP" 2>/dev/null || \
    echo "   (codesign skipped/failed — bundle still runnable locally)"

echo "==> Done: $ROOT/$APP"
echo "    Launch with:  open $APP"
echo "    Or:           ./$APP/Contents/MacOS/$APP_NAME"
