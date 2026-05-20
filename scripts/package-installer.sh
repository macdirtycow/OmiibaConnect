#!/usr/bin/env bash
# Build Omiiba Connect and create a macOS .pkg (fresh install or in-place update).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/DerivedData/Build/Products/Release/OmiibaConnect.app"
RELEASE_DIR="$ROOT/build/release"
INSTALLER_DIR="$ROOT/scripts/installer"
PKG_SCRIPTS="$INSTALLER_DIR/pkg-scripts"
STAGING="$RELEASE_DIR/pkg-staging"

# Version from info.plist
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Client/macos/info.plist")"
PKG_ID="dev.omiiba.connect"
COMPONENT_PKG="$STAGING/OmiibaConnect-component.pkg"
DIST_XML="$STAGING/distribution.xml"
FINAL_PKG="$RELEASE_DIR/OmiibaConnect-${VERSION}-macos-installer.pkg"
UPDATER_PKG="$RELEASE_DIR/OmiibaConnect-macos-updater.pkg"

echo "==> Building app..."
"$ROOT/scripts/build-macos.sh"

if [[ ! -d "$APP" ]]; then
  echo "error: app bundle not found at $APP" >&2
  exit 1
fi

rm -rf "$STAGING"
mkdir -p "$STAGING" "$RELEASE_DIR"

chmod +x "$PKG_SCRIPTS/preinstall" "$PKG_SCRIPTS/postinstall"

echo "==> Creating component package (preinstall quits app; postinstall finishes update)..."
pkgbuild \
  --component "$APP" \
  --install-location /Applications \
  --identifier "${PKG_ID}.app" \
  --version "$VERSION" \
  --scripts "$PKG_SCRIPTS" \
  "$COMPONENT_PKG"

echo "==> Creating installer package..."
sed "s/VERSION_PLACEHOLDER/$VERSION/g" "$INSTALLER_DIR/distribution.xml" > "$DIST_XML"

productbuild \
  --distribution "$DIST_XML" \
  --package-path "$STAGING" \
  --resources "$INSTALLER_DIR" \
  "$FINAL_PKG"

rm -rf "$STAGING"

cp -f "$FINAL_PKG" "$UPDATER_PKG"

echo ""
echo "Installer (install or update): $FINAL_PKG"
echo "Updater alias (same file):     $UPDATER_PKG"
echo "Open:   open \"$FINAL_PKG\""
echo ""
echo "Fast local update without .pkg: ./scripts/update-macos.sh"
