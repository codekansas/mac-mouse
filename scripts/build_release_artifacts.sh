#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="MacMouse"
VERSION_TAG="${1:-v0.1.0}"
OUTPUT_DIR="${2:-$ROOT_DIR/dist}"
VERSION="${VERSION_TAG#v}"
APP_BUNDLE_PATH="$OUTPUT_DIR/$PRODUCT_NAME.app"
DMG_STAGING_DIR="$OUTPUT_DIR/dmg"
DMG_PATH="$OUTPUT_DIR/$PRODUCT_NAME-$VERSION.dmg"
CHECKSUM_PATH="$OUTPUT_DIR/$PRODUCT_NAME-$VERSION.sha256"

rm -rf "$APP_BUNDLE_PATH" "$DMG_STAGING_DIR" "$DMG_PATH" "$CHECKSUM_PATH"
mkdir -p "$APP_BUNDLE_PATH/Contents/MacOS" "$APP_BUNDLE_PATH/Contents/Resources" "$DMG_STAGING_DIR"

swift build -c release --product "$PRODUCT_NAME"
BIN_PATH="$(swift build -c release --show-bin-path)/$PRODUCT_NAME"

cp "$BIN_PATH" "$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"
chmod 755 "$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"

cat >"$APP_BUNDLE_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.macmouse.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Without a paid Developer ID certificate, the best we can do in CI is ad-hoc
# signing. That keeps the bundle internally signed, but Gatekeeper will still
# treat downloads as coming from an unknown developer.
codesign --force --sign - --timestamp=none "$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"
codesign --force --sign - --timestamp=none "$APP_BUNDLE_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE_PATH"

cp -R "$APP_BUNDLE_PATH" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
    -volname "$PRODUCT_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

codesign --force --sign - --timestamp=none "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

shasum -a 256 "$DMG_PATH" > "$CHECKSUM_PATH"

echo "Created:"
echo "  $APP_BUNDLE_PATH"
echo "  $DMG_PATH"
echo "  $CHECKSUM_PATH"
