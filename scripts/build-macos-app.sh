#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXECUTABLE_NAME="LocalTranscript"
APP_NAME="Subly"
BUILD_ROOT="$ROOT_DIR/dist/build"
SCRATCH_PATH="$BUILD_ROOT/swiftpm"
MODULE_CACHE="$BUILD_ROOT/module-cache"
FAKE_HOME="$BUILD_ROOT/home"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
EXECUTABLE_PATH="$SCRATCH_PATH/release/$EXECUTABLE_NAME"
INFO_PLIST_SOURCE="$ROOT_DIR/packaging/App-Info.plist"
INFO_PLIST_TARGET="$APP_BUNDLE/Contents/Info.plist"
ICON_SOURCE="$ROOT_DIR/assets/app-icon.png"
ICONSET_DIR="$BUILD_ROOT/AppIcon.iconset"
ICON_OUTPUT="$APP_BUNDLE/Contents/Resources/AppIcon.icns"

rm -rf "$BUILD_ROOT" "$APP_BUNDLE"
mkdir -p "$SCRATCH_PATH" "$MODULE_CACHE" "$FAKE_HOME"

echo "Building $EXECUTABLE_NAME..."
HOME="$FAKE_HOME" \
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
swift build -c release --product "$EXECUTABLE_NAME" --scratch-path "$SCRATCH_PATH"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Executable not found at $EXECUTABLE_PATH" >&2
  exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Icon source not found at $ICON_SOURCE" >&2
  exit 1
fi

echo "Generating app icon..."
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

echo "Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
iconutil -c icns "$ICONSET_DIR" -o "$ICON_OUTPUT"
cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp "$INFO_PLIST_SOURCE" "$INFO_PLIST_TARGET"
cp -R "$ROOT_DIR/Backend" "$APP_BUNDLE/Contents/Resources/Backend"

if command -v codesign >/dev/null 2>&1; then
  echo "Applying ad-hoc code signature..."
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo
echo "App bundle ready:"
echo "  $APP_BUNDLE"
