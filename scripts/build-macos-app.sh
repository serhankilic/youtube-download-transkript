#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LocalTranscript"
BUILD_ROOT="$ROOT_DIR/dist/build"
SCRATCH_PATH="$BUILD_ROOT/swiftpm"
MODULE_CACHE="$BUILD_ROOT/module-cache"
FAKE_HOME="$BUILD_ROOT/home"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
EXECUTABLE_PATH="$SCRATCH_PATH/release/$APP_NAME"
INFO_PLIST_SOURCE="$ROOT_DIR/packaging/$APP_NAME-Info.plist"
INFO_PLIST_TARGET="$APP_BUNDLE/Contents/Info.plist"

rm -rf "$BUILD_ROOT" "$APP_BUNDLE"
mkdir -p "$SCRATCH_PATH" "$MODULE_CACHE" "$FAKE_HOME"

echo "Building $APP_NAME..."
HOME="$FAKE_HOME" \
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
swift build -c release --product "$APP_NAME" --scratch-path "$SCRATCH_PATH"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Executable not found at $EXECUTABLE_PATH" >&2
  exit 1
fi

echo "Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$INFO_PLIST_SOURCE" "$INFO_PLIST_TARGET"
cp -R "$ROOT_DIR/Backend" "$APP_BUNDLE/Contents/Resources/Backend"

if command -v codesign >/dev/null 2>&1; then
  echo "Applying ad-hoc code signature..."
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo
echo "App bundle ready:"
echo "  $APP_BUNDLE"
