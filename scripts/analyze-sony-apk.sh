#!/usr/bin/env bash
# Decompile Sony | Sound Connect APK and list MDR protocol-related sources.
#
# Usage:
#   ./scripts/analyze-sony-apk.sh                    # auto-pick best APK in ~/Downloads
#   ./scripts/analyze-sony-apk.sh path/to/app.apk    # specific file
#
# Note: small (~9 MB) "com.sony.songpal.mdr_1.0.x" APKMirror builds are often stubs
# without tandemfamily protocol classes. Use the full app (~60+ MB), e.g. Headphones-9.5.0.apk.
set -euo pipefail

pick_default_apk() {
  local best="" best_size=0 size path
  for path in \
    "$HOME/Downloads/Headphones-"*.apk \
    "$HOME/Downloads/"*songpal*mdr*.apk \
    "$HOME/Downloads/"*Headphones*.apk; do
    [[ -f "$path" ]] || continue
    size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null || echo 0)
    if [[ "$size" -gt "$best_size" ]]; then
      best="$path"
      best_size="$size"
    fi
  done
  if [[ -n "$best" ]]; then
    echo "$best"
    return 0
  fi
  return 1
}

if [[ $# -ge 1 ]]; then
  APK="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
else
  if ! APK="$(pick_default_apk)"; then
    echo "Usage: $0 <path/to/full-Sony-Headphones.apk>"
    echo "No Sony APK found in ~/Downloads"
    exit 1
  fi
  echo "Using largest APK in Downloads: $APK"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/tools/apk/decompiled"
APK_SIZE=$(stat -f%z "$APK" 2>/dev/null || stat -c%s "$APK" 2>/dev/null || echo 0)

if ! command -v jadx >/dev/null 2>&1; then
  echo "jadx not found. Install: brew install jadx"
  exit 1
fi

if [[ "$APK_SIZE" -lt 20000000 ]]; then
  echo "warning: APK is only $(( APK_SIZE / 1024 / 1024 )) MB — likely a stub without MDR protocol." >&2
  echo "warning: For protocol bytes use Headphones-9.5.0.apk (~63 MB) from APKMirror." >&2
fi

mkdir -p "$ROOT/tools/apk"
echo "Decompiling $APK -> $OUT"
rm -rf "$OUT"
set +e
jadx -q -d "$OUT" "$APK"
JADX_STATUS=$?
set -e
if [[ $JADX_STATUS -ne 0 ]]; then
  echo "note: jadx exited $JADX_STATUS (output may still be usable)" >&2
fi

CMD="$OUT/sources/com/sony/songpal/tandemfamily/message/mdr/v1/table1/Command.java"
echo ""
if [[ ! -f "$CMD" ]]; then
  echo "=== No MDR Command.java found ==="
  echo "This APK does not contain com.sony.songpal.tandemfamily.message.mdr."
  echo "Omiiba Connect protocol reference: use Headphones-9.5.0.apk (full app)."
  exit 3
fi

echo "=== MDR protocol (tandemfamily.message.mdr) ==="
find "$OUT" -path '*tandemfamily*message*mdr*' -name 'Command.java' 2>/dev/null

echo ""
echo "=== Key command bytes (table1) ==="
grep -E 'CONNECT_|COMMON_GET_BATTERY|COMMON_GET_AUDIO_CODEC|NCASM_GET_PARAM|EQEBB_GET_PARAM|GENERAL_SETTING_GET_PARAM|VPT_GET_PARAM' "$CMD" | head -25

echo ""
echo "=== Compare with Client/Constants.h ==="
HDR="$ROOT/Client/Constants.h"
for pair in "0x00:CONNECT_GET_PROTOCOL_INFO" "0x10:BATTERY_REQUEST" "0x18:AUDIO_CODEC_REQUEST" "0x66:NCASM_GET" "0x56:EQ_GET" "0xd6:TOUCH_GET"; do
  byte="${pair%%:*}"
  name="${pair##*:}"
  if grep -q "$name = $byte" "$HDR" 2>/dev/null || grep -qi "$name.*$byte" "$HDR" 2>/dev/null; then
    echo "  OK  $name ($byte)"
  else
    echo "  ??  $name ($byte) — check Constants.h"
  fi
done

echo ""
echo "Decompiled sources: $OUT"
echo "See docs/apk-reference.md"
