#!/bin/bash
# Local development build: ad-hoc signed, not distributable. See release.sh for that.
set -e
cd "$(dirname "$0")"

APP="POMO.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/ "$APP/Contents/Resources/"

swiftc -O Sources/*.swift -o "$APP/Contents/MacOS/POMO"

codesign --force --sign - "$APP"

echo "built $APP"
