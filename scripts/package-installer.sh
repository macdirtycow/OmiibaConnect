#!/usr/bin/env bash
# Build Omiiba Connect and create a macOS .pkg installer (installs to /Applications).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/DerivedData/Build/Products/Release/OmiibaConnect.app"
RELEASE_DIR="$ROOT/build/release"
INSTALLER_DIR="$ROOT/scripts/installer"
STAGING="$RELEASE_DIR/pkg-staging"

# Version from info.plist
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Client/macos/info.plist")"
PKG_ID="dev.omiiba.connect"
COMPONENT_PKG="$STAGING/OmiibaConnect-component.pkg"
DIST_XML="$STAGING/distribution.xml"
FINAL_PKG="$RELEASE_DIR/OmiibaConnect-${VERSION}-macos-installer.pkg"

echo "==> Building app..."
"$ROOT/scripts/build-macos.sh"

if [[ ! -d "$APP" ]]; then
  echo "error: app bundle not found at $APP" >&2
  exit 1
fi

rm -rf "$STAGING"
mkdir -p "$STAGING" "$RELEASE_DIR"

echo "==> Creating component package..."
pkgbuild \
  --component "$APP" \
  --install-location /Applications \
  --identifier "${PKG_ID}.app" \
  --version "$VERSION" \
  "$COMPONENT_PKG"

echo "==> Creating installer package..."
sed "s/VERSION_PLACEHOLDER/$VERSION/g" "$INSTALLER_DIR/distribution.xml" > "$DIST_XML"

productbuild \
  --distribution "$DIST_XML" \
  --package-path "$STAGING" \
  --resources "$INSTALLER_DIR" \
  "$FINAL_PKG"

rm -rf "$STAGING"

echo ""
echo "Installer: $FINAL_PKG"
echo "Install:   open \"$FINAL_PKG\""
