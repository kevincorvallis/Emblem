#!/bin/bash
# Builds Emblem.app (Release), signs it, optionally notarizes, and packages a DMG.
#
# Signing modes (auto-detected):
#   - Developer ID:  if a "Developer ID Application" identity is in the keychain
#                    (or SIGN_IDENTITY is set), sign with hardened runtime.
#   - Ad-hoc:        otherwise, or when CODE_SIGN_IDENTITY="-" is exported (CI).
#
# Notarization runs when signing with Developer ID AND either:
#   - NOTARY_PROFILE is set (a `xcrun notarytool store-credentials` profile), or
#   - NOTARY_KEY_ID / NOTARY_KEY_ISSUER / NOTARY_KEY_PATH are all set (CI).
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Resolve signing identity -------------------------------------------------
IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ] && [ "${CODE_SIGN_IDENTITY:-}" = "-" ]; then
  IDENTITY="-"
fi
if [ -z "$IDENTITY" ]; then
  if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    IDENTITY="Developer ID Application"
  else
    IDENTITY="-"
  fi
fi
echo "Signing identity: $IDENTITY"

# --- Build (unsigned; we sign the final bundle ourselves) ----------------------
xcodebuild \
  -project Emblem.xcodeproj \
  -scheme Emblem \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  build

APP="$BUILD_DIR/DerivedData/Build/Products/Release/Emblem.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

# --- Sign inside-out ------------------------------------------------------------
RUNTIME_ARGS=()
if [ "$IDENTITY" != "-" ]; then
  RUNTIME_ARGS=(--options runtime --timestamp)
fi

TEMPLATE="$APP/Contents/Resources/IconAppTemplate.app"
codesign --force --sign "$IDENTITY" "${RUNTIME_ARGS[@]+"${RUNTIME_ARGS[@]}"}" \
  "$TEMPLATE/Contents/PlugIns/IconAppSync.appex"
codesign --force --sign "$IDENTITY" "${RUNTIME_ARGS[@]+"${RUNTIME_ARGS[@]}"}" "$TEMPLATE"
codesign --force --sign "$IDENTITY" "${RUNTIME_ARGS[@]+"${RUNTIME_ARGS[@]}"}" \
  "$APP/Contents/Frameworks/EmblemCore.framework"
codesign --force --sign "$IDENTITY" "${RUNTIME_ARGS[@]+"${RUNTIME_ARGS[@]}"}" "$APP"
codesign --verify --deep --strict "$APP"
echo "Signed and verified."

# --- Notarize (Developer ID only) ----------------------------------------------
if [ "$IDENTITY" != "-" ]; then
  NOTARY_ARGS=()
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
  elif [ -n "${NOTARY_KEY_ID:-}" ] && [ -n "${NOTARY_KEY_ISSUER:-}" ] && [ -n "${NOTARY_KEY_PATH:-}" ]; then
    NOTARY_ARGS=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_KEY_ISSUER")
  fi

  if [ "${#NOTARY_ARGS[@]}" -gt 0 ]; then
    echo "Notarizing…"
    ditto -c -k --keepParent "$APP" "$BUILD_DIR/Emblem-notarize.zip"
    xcrun notarytool submit "$BUILD_DIR/Emblem-notarize.zip" "${NOTARY_ARGS[@]}" --wait
    xcrun stapler staple "$APP"
    echo "Notarized and stapled."
  else
    echo "No notary credentials found — skipping notarization." >&2
  fi
fi

# --- DMG ------------------------------------------------------------------------
STAGING="$BUILD_DIR/dmg-staging"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

DMG="$BUILD_DIR/Emblem-$VERSION.dmg"
hdiutil create -volname "Emblem $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "Created $DMG"
shasum -a 256 "$DMG"
