#!/bin/bash
# Builds "Navidrome Control.app" into ./dist (universal: Apple silicon + Intel).
# Add --install to also copy it into /Applications.
set -e
cd "$(dirname "$0")"
APP="dist/Navidrome Control.app"
SRC="src/NavidromeControl.swift"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BIN="$APP/Contents/MacOS/NavidromeControl"
TMP="$(mktemp -d)"
if swiftc -parse-as-library -O -swift-version 5 -target arm64-apple-macos13.0 "$SRC" -o "$TMP/arm64" \
   && swiftc -parse-as-library -O -swift-version 5 -target x86_64-apple-macos13.0 "$SRC" -o "$TMP/x86_64"; then
  lipo -create "$TMP/arm64" "$TMP/x86_64" -output "$BIN"
else
  echo "Universal build failed; building for this Mac only."
  swiftc -parse-as-library -O -swift-version 5 "$SRC" -o "$BIN"
fi
rm -rf "$TMP"
cp icon/NavidromeControl.icns "$APP/Contents/Resources/NavidromeControl.icns"
cat > "$APP/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleExecutable</key><string>NavidromeControl</string>
<key>CFBundleIdentifier</key><string>local.navidrome.control</string>
<key>CFBundleName</key><string>Navidrome Control</string>
<key>CFBundleDisplayName</key><string>Navidrome Control</string>
<key>CFBundleIconFile</key><string>NavidromeControl</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PL
codesign --force --sign - "$APP"
touch "$APP"
if [ "$1" = "--install" ]; then
  rm -rf "/Applications/Navidrome Control.app"
  cp -R "$APP" /Applications/
  echo "Installed to /Applications"
fi
echo BUILT
