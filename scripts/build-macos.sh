#!/usr/bin/env bash
# Build Omiiba Connect app. Skips Xcode's bundle CodeSign step (often fails on @ xattrs),
# then signs the binary and .app manually with Bluetooth entitlements.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/build/DerivedData"
ENTITLEMENTS="$ROOT/Client/macos/SonyHeadphonesClient.entitlements"
APP="$DERIVED/Build/Products/Release/OmiibaConnect.app"
BIN="$APP/Contents/MacOS/OmiibaConnect"

cd "$ROOT/Client/macos"

echo "Building (CodeSign disabled in xcodebuild; we sign after)..."
set +e
xcodebuild \
  -project SonyHeadphonesClient.xcodeproj \
  -scheme SonyHeadphonesClient \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build
XCODE_STATUS=$?
set -e

if [[ ! -f "$BIN" ]]; then
  echo "error: build did not produce $BIN (xcodebuild exit $XCODE_STATUS)" >&2
  exit 1
fi

if [[ $XCODE_STATUS -ne 0 ]]; then
  echo "note: xcodebuild exited $XCODE_STATUS (often CodeSign); continuing with manual sign."
fi

echo "Signing..."
xattr -cr "$APP" 2>/dev/null || true
/usr/bin/codesign --force --sign - "$BIN"
/usr/bin/codesign --force --deep --sign - \
  --entitlements "$ENTITLEMENTS" \
  "$APP"

if ! /usr/bin/codesign --verify --deep --strict "$APP" 2>/dev/null; then
  echo "warning: codesign verify reported an issue; app may still run locally." >&2
fi

echo ""
echo "Built: $APP"
echo "Run: open \"$APP\""
