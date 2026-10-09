#!/bin/bash
# Builds build/AutoQuit.app (ad-hoc signed). Use --install to copy it to ~/Applications and launch it.
set -euo pipefail
cd "$( dirname "$0" )/.."

swift build -c release
BIN="$( swift build -c release --show-bin-path )/AutoQuit"

APP="build/AutoQuit.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/AutoQuit"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --deep "$APP"
codesign --verify --verbose "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
    rm -rf "$DEST/AutoQuit.app"
    cp -R "$APP" "$DEST/AutoQuit.app"
    echo "Installed $DEST/AutoQuit.app"
    open "$DEST/AutoQuit.app"
fi
