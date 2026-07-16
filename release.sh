#!/bin/bash
# Builds a signed, notarized POMO.dmg that opens on any Mac without warnings.
#
# One-time setup (see README):
#   1. Join the Apple Developer Program and create a "Developer ID Application" certificate.
#   2. export POMO_SIGN_ID="Developer ID Application: Your Name (TEAMID)"
#   3. xcrun notarytool store-credentials POMO --apple-id <id> --team-id <TEAMID> --password <app-specific-password>
set -e
cd "$(dirname "$0")"

: "${POMO_SIGN_ID:?set POMO_SIGN_ID to your Developer ID Application identity}"
KEYCHAIN_PROFILE="${POMO_NOTARY_PROFILE:-POMO}"

APP="POMO.app"
DMG="POMO.dmg"

# 1. Build fresh.
rm -rf "$APP" "$DMG"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/ "$APP/Contents/Resources/"
swiftc -O Sources/*.swift -o "$APP/Contents/MacOS/POMO"

# 2. Sign with hardened runtime — notarization rejects anything else.
codesign --force --options runtime --timestamp --sign "$POMO_SIGN_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

# 3. Package as a drag-to-Applications disk image.
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname POMO -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

# 4. Notarize the disk image, then staple the ticket so it works offline.
codesign --force --timestamp --sign "$POMO_SIGN_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$DMG"

# 5. Prove it: this is what Gatekeeper will say on someone else's Mac.
spctl --assess --type open --context context:primary-signature -vv "$DMG"

echo
echo "ready to ship: $DMG"
