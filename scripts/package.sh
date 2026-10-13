#!/bin/sh
# Builds a universal Saaclipboard.app, signs it, and packs it into a .zip and .dmg in dist/.
#   SIGN_ID         codesign identity; a "Developer ID Application: …" cert is needed for others to open it.
#                   Defaults to ad-hoc ("-"), which only runs on this Mac.
#   NOTARY_PROFILE  notarytool keychain profile (xcrun notarytool store-credentials). If set, notarizes and staples.
set -eu
cd "$(dirname "$0")/.."

APP=dist/Saaclipboard.app
SIGN_ID=${SIGN_ID:--}
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Support/Info.plist)

swift build -c release --arch arm64 --arch x86_64
rm -rf dist && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/apple/Products/Release/Saaclipboard "$APP/Contents/MacOS/"
cp Support/Info.plist "$APP/Contents/"
cp Support/AppIcon.icns "$APP/Contents/Resources/"

codesign --force --options runtime --timestamp=none --sign "$SIGN_ID" "$APP"
[ "$SIGN_ID" != "-" ] && codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
codesign --verify --strict "$APP"

ZIP=dist/Saaclipboard-$VERSION.zip
DMG=dist/Saaclipboard-$VERSION.dmg
ditto -c -k --keepParent "$APP" "$ZIP"

if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    rm "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"
fi

mkdir dist/dmg && cp -R "$APP" dist/dmg/ && ln -s /Applications dist/dmg/Applications
hdiutil create -volname Saaclipboard -srcfolder dist/dmg -ov -format UDZO "$DMG" >/dev/null
rm -rf dist/dmg
[ "$SIGN_ID" != "-" ] && codesign --sign "$SIGN_ID" --timestamp "$DMG"
[ -n "${NOTARY_PROFILE:-}" ] && xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait && xcrun stapler staple "$DMG"

echo "Built $ZIP and $DMG"
