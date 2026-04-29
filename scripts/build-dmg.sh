#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LocalTranscript"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
STAGING_DIR="$ROOT_DIR/dist/dmg"
DMG_PATH="$ROOT_DIR/dist/$APP_NAME.dmg"

if [[ ! -d "$APP_BUNDLE" ]]; then
  "$ROOT_DIR/scripts/build-macos-app.sh"
fi

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating DMG..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo
echo "DMG ready:"
echo "  $DMG_PATH"
