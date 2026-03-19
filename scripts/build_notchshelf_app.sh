#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/NotchShelf.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$BUILD_DIR"
rm -f "$BUILD_DIR/NotchShelf"
rm -rf "$APP_DIR"

swiftc \
  "$ROOT_DIR/NotchShelf/NotchShelfApp.swift" \
  "$ROOT_DIR/NotchShelf/Models/ScreenshotItem.swift" \
  "$ROOT_DIR/NotchShelf/Services/PersistenceService.swift" \
  "$ROOT_DIR/NotchShelf/Services/ThumbnailService.swift" \
  "$ROOT_DIR/NotchShelf/Services/BookmarkStore.swift" \
  "$ROOT_DIR/NotchShelf/Services/DirectoryWatcher.swift" \
  "$ROOT_DIR/NotchShelf/Services/ScreenshotStore.swift" \
  "$ROOT_DIR/NotchShelf/Services/WatchedFolderController.swift" \
  "$ROOT_DIR/NotchShelf/UI/DebugWindowController.swift" \
  "$ROOT_DIR/NotchShelf/UI/ShelfItemDragWriter.swift" \
  "$ROOT_DIR/NotchShelf/UI/ShelfItemView.swift" \
  "$ROOT_DIR/NotchShelf/UI/ShelfView.swift" \
  "$ROOT_DIR/NotchShelf/UI/ShelfWindowController.swift" \
  "$ROOT_DIR/NotchShelf/UI/StatusItemController.swift" \
  "$ROOT_DIR/NotchShelf/Utilities/NSView+Layout.swift" \
  "$ROOT_DIR/NotchShelf/Utilities/NSImage+Encoding.swift" \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  -framework CryptoKit \
  -o "$BUILD_DIR/NotchShelf"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/NotchShelf" "$MACOS_DIR/NotchShelf"
cp "$ROOT_DIR/NotchShelf/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

plutil -replace CFBundleDevelopmentRegion -string en "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleExecutable -string NotchShelf "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleIdentifier -string com.local.NotchShelf "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleName -string NotchShelf "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built $APP_DIR"
