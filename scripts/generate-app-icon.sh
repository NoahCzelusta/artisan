#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/Resources/AppIcon.svg"
ICONSET="$ROOT_DIR/.scratch/app-icon.iconset"
PNG_1024="$ROOT_DIR/Resources/AppIcon.png"
ICNS="$ROOT_DIR/Resources/AppIcon.icns"

fail() {
  echo "generate-app-icon: $*" >&2
  exit 1
}

command -v rsvg-convert >/dev/null 2>&1 || fail "rsvg-convert is required"
command -v iconutil >/dev/null 2>&1 || fail "iconutil is required"
test -f "$SOURCE" || fail "missing $SOURCE"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

render_png() {
  local size="$1"
  local output="$2"
  rsvg-convert -w "$size" -h "$size" "$SOURCE" -o "$output"
}

render_png 1024 "$PNG_1024"
render_png 16 "$ICONSET/icon_16x16.png"
render_png 32 "$ICONSET/icon_16x16@2x.png"
render_png 32 "$ICONSET/icon_32x32.png"
render_png 64 "$ICONSET/icon_32x32@2x.png"
render_png 128 "$ICONSET/icon_128x128.png"
render_png 256 "$ICONSET/icon_128x128@2x.png"
render_png 256 "$ICONSET/icon_256x256.png"
render_png 512 "$ICONSET/icon_256x256@2x.png"
render_png 512 "$ICONSET/icon_512x512.png"
render_png 1024 "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ICNS"
echo "$ICNS"
