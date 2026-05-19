#!/usr/bin/env bash
# Decompile Sony | Sound Connect APK and list MDR protocol-related sources.
# Usage: ./scripts/analyze-sony-apk.sh path/to/com.sony.songpal.mdr.apk
set -euo pipefail

DEFAULT_APK="$HOME/Downloads/Headphones-9.5.0.apk"

if [[ $# -lt 1 ]]; then
  if [[ -f "$DEFAULT_APK" ]]; then
    APK="$DEFAULT_APK"
    echo "Using default: $APK"
  else
    echo "Usage: $0 <path/to/Headphones.apk>"
    echo "Default tried: $DEFAULT_APK"
    exit 1
  fi
else
  APK="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/tools/apk/decompiled"

if ! command -v jadx >/dev/null 2>&1; then
  echo "jadx not found. Install: brew install jadx"
  exit 1
fi

mkdir -p "$ROOT/tools/apk"
echo "Decompiling $APK -> $OUT"
rm -rf "$OUT"
jadx -q -d "$OUT" "$APK"

echo ""
echo "=== MDR protocol Java paths (tandemfamily.message.mdr) ==="
find "$OUT" -path '*tandemfamily*message*mdr*' -name '*.java' 2>/dev/null | head -40

echo ""
echo "=== Command.java (table1) ==="
CMD="$OUT/sources/com/sony/songpal/tandemfamily/message/mdr/v1/table1/Command.java"
if [[ -f "$CMD" ]]; then
  grep -E '^\s+[A-Z_]+\(' "$CMD" | head -30
else
  grep -r 'CONNECT_GET_PROTOCOL_INFO' "$OUT/sources" 2>/dev/null | head -5
fi

echo ""
echo "Open in IDE: $OUT"
echo "See docs/sony-apk-analysis.md for what to look for."
