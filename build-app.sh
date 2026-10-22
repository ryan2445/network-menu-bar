#!/bin/bash
set -euo pipefail

APP_NAME="Network Menu Bar"
BUNDLE_NAME="Network Menu Bar.app"
EXECUTABLE_NAME="network-menu-bar"

echo "Building release binary..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$BUNDLE_NAME"
mkdir -p "$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$BUNDLE_NAME/Contents/Resources"

cp .build/release/$EXECUTABLE_NAME "$BUNDLE_NAME/Contents/MacOS/"
cp Info.plist "$BUNDLE_NAME/Contents/"

echo "Signing app bundle (ad-hoc)..."
codesign --force --deep --sign - "$BUNDLE_NAME"

echo "Verifying code signature..."
codesign --verify --deep --strict "$BUNDLE_NAME"

echo "Done! App bundle created: $BUNDLE_NAME"
echo ""
echo "To install, run:"
echo "  cp -r \"$BUNDLE_NAME\" /Applications/"
echo ""
echo "Then launch from /Applications or Spotlight."

if [ "${1:-}" = "--dmg" ]; then
  echo ""
  echo "Generating DMG distribution..."
  ./scripts/create-dmg.sh "${2:-1.0.0}"
fi
