#!/usr/bin/env bash
# Build (if needed) and update /Applications/OmiibaConnect.app without the .pkg wizard.
# Use this for day-to-day development; use the .pkg for a normal install on a new Mac.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/DerivedData/Build/Products/Release/OmiibaConnect.app"
INSTALL_PATH="/Applications/OmiibaConnect.app"
PLIST="$ROOT/Client/macos/info.plist"

need_sudo() {
	[[ ! -w /Applications ]]
}

run_as_root() {
	if need_sudo; then
		echo "Administrator rights are required to write to /Applications."
		exec sudo -E "$0" "$@"
	fi
}

run_as_root "$@"

if [[ ! -d "$APP" ]] || [[ "${1:-}" == "--build" ]] || [[ "${1:-}" == "-b" ]]; then
	echo "==> Building Omiiba Connect..."
	"$ROOT/scripts/build-macos.sh"
fi

if [[ ! -d "$APP" ]]; then
	echo "error: app bundle not found at $APP" >&2
	exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST" 2>/dev/null || echo "?")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PLIST" 2>/dev/null || echo "?")"

echo "==> Stopping Omiiba Connect if it is running..."
osascript -e 'tell application "Omiiba Connect" to quit' 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
	pgrep -x OmiibaConnect >/dev/null 2>&1 || break
	sleep 0.3
done
killall OmiibaConnect 2>/dev/null || true

if [[ -d "$INSTALL_PATH" ]]; then
	echo "==> Updating $INSTALL_PATH (v${VERSION} build ${BUILD})..."
	rm -rf "$INSTALL_PATH"
else
	echo "==> Installing to $INSTALL_PATH (v${VERSION} build ${BUILD})..."
fi

ditto "$APP" "$INSTALL_PATH"
xattr -cr "$INSTALL_PATH" 2>/dev/null || true

echo ""
echo "Done. Omiiba Connect ${VERSION} (${BUILD}) is in Applications."
if [[ "${OPEN_AFTER:-1}" != "0" ]]; then
	open "$INSTALL_PATH"
fi
