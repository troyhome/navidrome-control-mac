#!/bin/bash
# Builds the app, then packs it into dist/NavidromeControl.dmg
set -e
cd "$(dirname "$0")"
bash build.sh
rm -rf dist/dmg
mkdir -p dist/dmg
cp -R "dist/Navidrome Control.app" dist/dmg/
ln -s /Applications dist/dmg/Applications
hdiutil create -volname "Navidrome Control" -srcfolder dist/dmg -ov -format UDZO dist/NavidromeControl.dmg
rm -rf dist/dmg
echo "DMG ready: $(pwd)/dist/NavidromeControl.dmg"
