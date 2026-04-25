#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="MacMouse"
VERSION_TAG="${1:-v0.1.0}"
OUTPUT_DIR="${2:-$ROOT_DIR/dist/app-store}"
VERSION="${VERSION_TAG#v}"
APP_BUNDLE_PATH="$OUTPUT_DIR/$PRODUCT_NAME.app"
PKG_PATH="$OUTPUT_DIR/$PRODUCT_NAME-$VERSION-app-store.pkg"
CHECKSUM_PATH="$OUTPUT_DIR/$PRODUCT_NAME-$VERSION-app-store.sha256"
ICON_SOURCE_PATH="$ROOT_DIR/Sources/MacMouse/Resources/MouseIcon.png"
ENTITLEMENTS_PATH="$ROOT_DIR/Signing/MacMouse-AppStore.entitlements"
ICON_FILE_NAME="$PRODUCT_NAME.icns"

APP_SIGNING_IDENTITY="${MACMOUSE_APP_STORE_APPLICATION_IDENTITY:-}"
INSTALLER_SIGNING_IDENTITY="${MACMOUSE_APP_STORE_INSTALLER_IDENTITY:-}"
SIGNING_KEYCHAIN="${MACMOUSE_SIGNING_KEYCHAIN:-}"
PROVISIONING_PROFILE_PATH="${MACMOUSE_APP_STORE_PROVISIONING_PROFILE:-}"
UPLOAD_TO_APP_STORE="${MACMOUSE_UPLOAD_TO_APP_STORE:-0}"
APP_STORE_CONNECT_API_KEY_ID="${MACMOUSE_APP_STORE_CONNECT_API_KEY_ID:-}"
APP_STORE_CONNECT_API_ISSUER_ID="${MACMOUSE_APP_STORE_CONNECT_API_ISSUER_ID:-}"
APP_STORE_CONNECT_API_PRIVATE_KEY="${MACMOUSE_APP_STORE_CONNECT_API_PRIVATE_KEY:-}"

if [[ ! "$VERSION_TAG" =~ '^v[0-9][0-9A-Za-z._-]*$' ]]; then
    echo "Expected a release tag like v0.1.0, got: $VERSION_TAG" >&2
    exit 1
fi

if [[ -z "$APP_SIGNING_IDENTITY" ]]; then
    echo "MACMOUSE_APP_STORE_APPLICATION_IDENTITY is required." >&2
    exit 1
fi

if [[ -z "$INSTALLER_SIGNING_IDENTITY" ]]; then
    echo "MACMOUSE_APP_STORE_INSTALLER_IDENTITY is required." >&2
    exit 1
fi

if [[ -z "$PROVISIONING_PROFILE_PATH" || ! -f "$PROVISIONING_PROFILE_PATH" ]]; then
    echo "MACMOUSE_APP_STORE_PROVISIONING_PROFILE must point to a Mac App Store provisioning profile." >&2
    exit 1
fi

CODESIGN_SIGNING_ARGS=()
PRODUCTBUILD_SIGNING_ARGS=()
if [[ -n "$SIGNING_KEYCHAIN" ]]; then
    CODESIGN_SIGNING_ARGS+=(--keychain "$SIGNING_KEYCHAIN")
    PRODUCTBUILD_SIGNING_ARGS+=(--keychain "$SIGNING_KEYCHAIN")
fi

rm -rf "$APP_BUNDLE_PATH" "$PKG_PATH" "$CHECKSUM_PATH"
mkdir -p "$APP_BUNDLE_PATH/Contents/MacOS" "$APP_BUNDLE_PATH/Contents/Resources"

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
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Benjamin Bolte. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

cp "$PROVISIONING_PROFILE_PATH" "$APP_BUNDLE_PATH/Contents/embedded.provisionprofile"

codesign --force --timestamp --options runtime "${CODESIGN_SIGNING_ARGS[@]}" \
    --entitlements "$ENTITLEMENTS_PATH" \
    --sign "$APP_SIGNING_IDENTITY" \
    "$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"
codesign --force --timestamp --options runtime "${CODESIGN_SIGNING_ARGS[@]}" \
    --entitlements "$ENTITLEMENTS_PATH" \
    --sign "$APP_SIGNING_IDENTITY" \
    "$APP_BUNDLE_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE_PATH"

productbuild "${PRODUCTBUILD_SIGNING_ARGS[@]}" \
    --sign "$INSTALLER_SIGNING_IDENTITY" \
    --component "$APP_BUNDLE_PATH" /Applications \
    "$PKG_PATH"
pkgutil --check-signature "$PKG_PATH"

shasum -a 256 "$PKG_PATH" > "$CHECKSUM_PATH"

echo "Created:"
echo "  $APP_BUNDLE_PATH"
echo "  $PKG_PATH"
echo "  $CHECKSUM_PATH"

if [[ "$UPLOAD_TO_APP_STORE" == "1" ]]; then
    if [[ -z "$APP_STORE_CONNECT_API_KEY_ID" || -z "$APP_STORE_CONNECT_API_ISSUER_ID" || -z "$APP_STORE_CONNECT_API_PRIVATE_KEY" ]]; then
        echo "App Store upload requires MACMOUSE_APP_STORE_CONNECT_API_KEY_ID, MACMOUSE_APP_STORE_CONNECT_API_ISSUER_ID, and MACMOUSE_APP_STORE_CONNECT_API_PRIVATE_KEY." >&2
        exit 1
    fi

    KEY_DIR="$HOME/.appstoreconnect/private_keys"
    KEY_PATH="$KEY_DIR/AuthKey_$APP_STORE_CONNECT_API_KEY_ID.p8"
    mkdir -p "$KEY_DIR"
    printf '%s\n' "$APP_STORE_CONNECT_API_PRIVATE_KEY" > "$KEY_PATH"
    chmod 600 "$KEY_PATH"

    xcrun altool --validate-app \
        -f "$PKG_PATH" \
        -t macos \
        --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"
    xcrun altool --upload-app \
        -f "$PKG_PATH" \
        -t macos \
        --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_API_ISSUER_ID"
fi
