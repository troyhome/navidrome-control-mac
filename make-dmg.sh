#!/bin/bash
# Builds the app, then packs it into dist/NavidromeControl.dmg
set -e
cd "$(dirname "$0")"
[ -f signing.env ] && source signing.env
bash build.sh
rm -rf dist/dmg
mkdir -p dist/dmg
cp -R "dist/Navidrome Control.app" dist/dmg/
ln -s /Applications dist/dmg/Applications
hdiutil create -volname "Navidrome Control" -srcfolder dist/dmg -ov -format UDZO dist/NavidromeControl.dmg
if [ -n "$SIGN_ID" ]; then
  codesign --force --timestamp --sign "$SIGN_ID" dist/NavidromeControl.dmg
  if [ -n "$NOTARY_PROFILE" ]; then
    echo "Sending to Apple for notarization (a few minutes)..."
    xcrun notarytool submit dist/NavidromeControl.dmg --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple dist/NavidromeControl.dmg
  fi
fi
rm -rf dist/dmg
echo "DMG ready: $(pwd)/dist/NavidromeControl.dmg"
