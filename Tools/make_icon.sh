#!/bin/bash
# Regenerates Resources/POMO.icns from make_icon.swift. Run only when the icon changes.
set -e
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)/POMO.iconset
swift Tools/make_icon.swift "$TMP"
iconutil -c icns "$TMP" -o Resources/POMO.icns

echo "wrote Resources/POMO.icns"
