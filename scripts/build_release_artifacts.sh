#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="MacMouse"
VERSION_TAG="${1:-v0.1.0}"
OUTPUT_DIR="${2:-$ROOT_DIR/dist}"
VERSION="${VERSION_TAG#v}"
APP_BUNDLE_PATH="$OUTPUT_DIR/$PRODUCT_NAME.app"
ZIP_PATH="$OUTPUT_DIR/$PRODUCT_NAME-$VERSION.zip"
CHECKSUM_PATH="$OUTPUT_DIR/$PRODUCT_NAME-$VERSION.sha256"
ICON_SOURCE_PATH="$ROOT_DIR/Sources/MacMouse/Resources/MouseIcon.png"
ICON_FILE_NAME="$PRODUCT_NAME.icns"
NOTARY_TEMP_DIR="$OUTPUT_DIR/notary"
NOTARY_ZIP_PATH="$NOTARY_TEMP_DIR/$PRODUCT_NAME-$VERSION-notary.zip"

SIGNING_IDENTITY="${MACMOUSE_SIGNING_IDENTITY:-}"
SIGNING_KEYCHAIN="${MACMOUSE_SIGNING_KEYCHAIN:-}"
NOTARY_APPLE_ID="${MACMOUSE_NOTARY_APPLE_ID:-}"
NOTARY_PASSWORD="${MACMOUSE_NOTARY_PASSWORD:-}"
NOTARY_TEAM_ID="${MACMOUSE_NOTARY_TEAM_ID:-}"
REQUIRE_DEVELOPER_ID_SIGNING="${MACMOUSE_REQUIRE_DEVELOPER_ID_SIGNING:-0}"

if [[ ! "$VERSION_TAG" =~ '^v[0-9][0-9A-Za-z._-]*$' ]]; then
    echo "Expected a release tag like v0.1.0, got: $VERSION_TAG" >&2
    exit 1
fi

rm -rf "$APP_BUNDLE_PATH" "$ZIP_PATH" "$CHECKSUM_PATH"
rm -rf "$NOTARY_TEMP_DIR"
mkdir -p \
    "$APP_BUNDLE_PATH/Contents/MacOS" \
    "$APP_BUNDLE_PATH/Contents/Resources" \
    "$NOTARY_TEMP_DIR"

if [[ -z "$SIGNING_IDENTITY" ]]; then
    FIND_IDENTITY_ARGS=(-v -p codesigning)
    if [[ -n "$SIGNING_KEYCHAIN" ]]; then
        FIND_IDENTITY_ARGS+=("$SIGNING_KEYCHAIN")
    fi
    SIGNING_IDENTITY="$(
        security find-identity "${FIND_IDENTITY_ARGS[@]}" 2>/dev/null \
            | sed -n 's/.*"\\(Developer ID Application:.*\\)"/\\1/p' \
            | head -n 1
    )"
fi

CODESIGN_SIGNING_ARGS=()
if [[ -n "$SIGNING_KEYCHAIN" ]]; then
    CODESIGN_SIGNING_ARGS+=(--keychain "$SIGNING_KEYCHAIN")
fi

HAS_SIGNING_IDENTITY=0
HAS_NOTARY_CREDENTIALS=0
HAS_PARTIAL_NOTARY_CREDENTIALS=0

if [[ -n "$SIGNING_IDENTITY" ]]; then
    HAS_SIGNING_IDENTITY=1
fi

if [[ -n "$NOTARY_APPLE_ID" && -n "$NOTARY_PASSWORD" && -n "$NOTARY_TEAM_ID" ]]; then
    HAS_NOTARY_CREDENTIALS=1
fi

if [[ -n "$NOTARY_APPLE_ID" || -n "$NOTARY_PASSWORD" || -n "$NOTARY_TEAM_ID" ]]; then
    HAS_PARTIAL_NOTARY_CREDENTIALS=1
fi

if (( HAS_PARTIAL_NOTARY_CREDENTIALS && ! HAS_NOTARY_CREDENTIALS )); then
    echo "Notarization credentials are incomplete." >&2
    echo "Provide MACMOUSE_NOTARY_APPLE_ID, MACMOUSE_NOTARY_PASSWORD, and MACMOUSE_NOTARY_TEAM_ID together." >&2
    exit 1
fi

if (( HAS_NOTARY_CREDENTIALS && ! HAS_SIGNING_IDENTITY )); then
    echo "Notarization requires a Developer ID signing identity." >&2
    exit 1
fi

if [[ "$REQUIRE_DEVELOPER_ID_SIGNING" == "1" && -z "$SIGNING_IDENTITY" ]]; then
    echo "A Developer ID signing identity is required for this build." >&2
    exit 1
fi

swift build -c release --product "$PRODUCT_NAME"
BUILD_BIN_PATH="$(swift build -c release --show-bin-path)"
BIN_PATH="$BUILD_BIN_PATH/$PRODUCT_NAME"

cp "$BIN_PATH" "$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"
chmod 755 "$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"
find "$BUILD_BIN_PATH" -maxdepth 1 -type d -name '*.bundle' -exec cp -R {} "$APP_BUNDLE_PATH/Contents/Resources/" \;

if [[ -f "$ICON_SOURCE_PATH" ]]; then
    ICONSET_PATH="$OUTPUT_DIR/$PRODUCT_NAME.iconset"
    rm -rf "$ICONSET_PATH"
    mkdir -p "$ICONSET_PATH"

    # Build a standard macOS iconset from the generated source image.
    sips -z 16 16 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_16x16.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_32x32.png" >/dev/null
    sips -z 64 64 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_128x128.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_256x256.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_512x512.png" >/dev/null
    cp "$ICON_SOURCE_PATH" "$ICONSET_PATH/icon_512x512@2x.png"

    iconutil -c icns "$ICONSET_PATH" -o "$APP_BUNDLE_PATH/Contents/Resources/$ICON_FILE_NAME"
    rm -rf "$ICONSET_PATH"
fi

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
    <key>CFBundleIconFile</key>
    <string>$ICON_FILE_NAME</string>
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

if (( HAS_SIGNING_IDENTITY )); then
    codesign --force --timestamp --options runtime "${CODESIGN_SIGNING_ARGS[@]}" --sign "$SIGNING_IDENTITY" \
        "$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"
    codesign --force --timestamp --options runtime "${CODESIGN_SIGNING_ARGS[@]}" --sign "$SIGNING_IDENTITY" \
        "$APP_BUNDLE_PATH"

    if (( HAS_NOTARY_CREDENTIALS )); then
        ditto -c -k --keepParent "$APP_BUNDLE_PATH" "$NOTARY_ZIP_PATH"
        xcrun notarytool submit "$NOTARY_ZIP_PATH" \
            --apple-id "$NOTARY_APPLE_ID" \
            --password "$NOTARY_PASSWORD" \
            --team-id "$NOTARY_TEAM_ID" \
            --wait
        xcrun stapler staple "$APP_BUNDLE_PATH"
        xcrun stapler validate "$APP_BUNDLE_PATH"
        spctl --assess --verbose=2 --type execute "$APP_BUNDLE_PATH"
    fi
else
    # Without a paid Developer ID certificate, the best we can do in CI is
    # ad-hoc signing. Gatekeeper will still warn for downloaded builds.
    codesign --force --sign - --timestamp=none "$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"
    codesign --force --sign - --timestamp=none "$APP_BUNDLE_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE_PATH"

ditto -c -k --keepParent "$APP_BUNDLE_PATH" "$ZIP_PATH"

shasum -a 256 "$ZIP_PATH" > "$CHECKSUM_PATH"

echo "Created:"
echo "  $APP_BUNDLE_PATH"
echo "  $ZIP_PATH"
echo "  $CHECKSUM_PATH"

if (( HAS_SIGNING_IDENTITY && HAS_NOTARY_CREDENTIALS )); then
    echo "  notarized with Developer ID: $SIGNING_IDENTITY"
elif (( HAS_SIGNING_IDENTITY )); then
    echo "  signed with Developer ID: $SIGNING_IDENTITY"
    echo "  not notarized; configure MACMOUSE_NOTARY_* credentials to notarize release builds"
else
    echo "  signed ad-hoc only; Gatekeeper will warn for downloaded builds"
fi
