#!/usr/bin/env bash
# Rebuild AppIcon.icns and menu-bar PNGs from Resources/brand/mark.png
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRAND="${ROOT}/Resources/brand"
SRC="${BRAND}/banner.jpg"
PAPER="srgb(201,197,188)"

[[ -f "$SRC" ]] || { echo "ERROR: missing $SRC" >&2; exit 1; }

magick "$SRC" -crop 920x1072+0+0 +repage -fuzz 12% -trim +repage "$BRAND/mark.png"
magick "$BRAND/mark.png" -resize x800 -background "$PAPER" -gravity center -extent 1024x1024 "$BRAND/logo.png"
magick "$BRAND/mark.png" -fuzz 14% -transparent "$PAPER" "$BRAND/logo-transparent.png"
magick "$SRC" -crop 900x500+980+280 +repage -fuzz 14% -trim +repage "$BRAND/wordmark.png"

ICONSET="${ROOT}/Resources/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for spec in 16:icon_16x16 32:icon_16x16@2x 32:icon_32x32 64:icon_32x32@2x \
            128:icon_128x128 256:icon_128x128@2x 256:icon_256x256 \
            512:icon_256x256@2x 512:icon_512x512 1024:icon_512x512@2x; do
  px="${spec%%:*}"
  name="${spec#*:}"
  magick "$BRAND/logo.png" -resize "${px}x${px}" "${ICONSET}/${name}.png"
done
iconutil -c icns "$ICONSET" -o "${ROOT}/Resources/AppIcon.icns"
rm -rf "$ICONSET"
cp "$BRAND/logo.png" "${ROOT}/Resources/AppIcon.png"

magick "$BRAND/logo.png" -resize 22x22 "${ROOT}/Resources/MenuBarIcon.png"
magick "$BRAND/logo.png" -resize 44x44 "${ROOT}/Resources/MenuBarIcon@2x.png"

echo "Wrote AppIcon.icns, logo.png, MenuBarIcon.png"
