#!/bin/bash
# Builds Emblem.app (Release) and packages it into build/Emblem-<version>.dmg.
# CODE_SIGN_IDENTITY env overrides the signing identity (default: project settings;
# CI passes "-" for ad-hoc).
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

SIGN_ARGS=()
if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
  SIGN_ARGS=(CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
fi

xcodebuild \
  -project Emblem.xcodeproj \
  -scheme Emblem \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  "${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"}" \
  build

APP="$BUILD_DIR/DerivedData/Build/Products/Release/Emblem.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

STAGING="$BUILD_DIR/dmg-staging"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

DMG="$BUILD_DIR/Emblem-$VERSION.dmg"
hdiutil create -volname "Emblem $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "Created $DMG"
