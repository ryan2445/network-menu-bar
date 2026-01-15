#!/bin/bash
set -e

APP_NAME="Network Menu Bar"
BUNDLE_NAME="Network Menu Bar.app"
EXECUTABLE_NAME="network-menu-bar"

echo "Building..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$BUNDLE_NAME"
mkdir -p "$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$BUNDLE_NAME/Contents/Resources"

cp .build/release/$EXECUTABLE_NAME "$BUNDLE_NAME/Contents/MacOS/"
cp Info.plist "$BUNDLE_NAME/Contents/"

echo "Done! App bundle created: $BUNDLE_NAME"
echo ""
echo "To install, run:"
echo "  cp -r \"$BUNDLE_NAME\" /Applications/"
echo ""
echo "Then launch from /Applications or Spotlight."
