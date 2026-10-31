#!/bin/bash
set -euo pipefail
# SPDX-License-Identifier: LicenseRef-BocaTechForce-Free-Use-No-Sale-1.0
# Copyright (c) 2026 BocaTechForce
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--no-launch" ) ]]; then
  echo "Usage: bash build.command [--no-launch]" >&2
  exit 2
fi
cd "$(dirname "$0")"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Run this script on your Mac."
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Apple Command Line Tools are needed. Run: xcode-select --install"
  exit 1
fi
APP="$PWD/build/MacShotEdgeRibbon.app"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MacShotEdgeRibbon</string>
<key>CFBundleIdentifier</key><string>com.bocatechforce.edgecapture.prototype</string>
<key>CFBundleName</key><string>MacShotEdgeRibbon</string>
<key>CFBundleDisplayName</key><string>MacShotEdgeRibbon</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.19</string>
<key>CFBundleVersion</key><string>19</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xcrun swiftc -swift-version 5 -O -framework AppKit main.swift -o "$APP/Contents/MacOS/MacShotEdgeRibbon"
mkdir -p "$APP/Contents/Resources"
ICONSET="$PWD/build/AppIcon.iconset"
xcrun swift make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built successfully: $APP"
echo "Copy MacShotEdgeRibbon.app to Applications before adding it to Login Items."
if [[ "${1:-}" != "--no-launch" ]]; then
  open -R "$APP"
  open "$APP"
fi
