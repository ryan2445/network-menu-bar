#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="Network Menu Bar"
BUNDLE_NAME="Network Menu Bar.app"
APP_PATH="$ROOT_DIR/$BUNDLE_NAME"
DIST_DIR="$ROOT_DIR/dist"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: $BUNDLE_NAME not found at $APP_PATH. Run ./build-app.sh first."
  exit 1
fi

echo "Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"

mkdir -p "$DIST_DIR"

VERSION="${1:-1.0.0}"
# Strip leading 'v' if provided
VERSION="${VERSION#v}"

DMG_FILE="$DIST_DIR/NetworkMenuBar-${VERSION}.dmg"
DMG_LATEST="$DIST_DIR/NetworkMenuBar.dmg"
ZIP_FILE="$DIST_DIR/NetworkMenuBar-${VERSION}.zip"
ZIP_LATEST="$DIST_DIR/NetworkMenuBar.zip"
CHECKSUMS_FILE="$DIST_DIR/checksums.txt"

STAGING_DIR="$(mktemp -d /tmp/dmg-staging.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "Staging DMG contents in $STAGING_DIR..."
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating compressed DMG: $DMG_FILE..."
rm -f "$DMG_FILE" "$DMG_LATEST"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_FILE"

cp "$DMG_FILE" "$DMG_LATEST"

echo "Creating ZIP archive: $ZIP_FILE..."
rm -f "$ZIP_FILE" "$ZIP_LATEST"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_FILE"
cp "$ZIP_FILE" "$ZIP_LATEST"

echo "Generating SHA256 checksums..."
cd "$DIST_DIR"
shasum -a 256 "NetworkMenuBar-${VERSION}.dmg" "NetworkMenuBar-${VERSION}.zip" > "$CHECKSUMS_FILE"

echo ""
echo "Packaging complete!"
echo "Artifacts generated in $DIST_DIR:"
ls -lh "$DIST_DIR"
cat "$CHECKSUMS_FILE"
