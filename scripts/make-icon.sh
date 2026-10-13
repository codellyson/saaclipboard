#!/bin/sh
# Rebuilds Support/AppIcon.icns from scripts/icon.swift.
set -eu
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
swift scripts/icon.swift "$TMP/icon.png"
mkdir "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o Support/AppIcon.icns
rm -rf "$TMP"
