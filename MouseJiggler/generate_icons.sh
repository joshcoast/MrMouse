#!/usr/bin/env bash
# generate_icons.sh
# Converts icon.svg to all required PNG sizes for the Xcode asset catalog.
# Requirements: Inkscape (brew install inkscape) OR rsvg-convert (brew install librsvg)
# Usage: ./generate_icons.sh

set -euo pipefail

SVG="icon.svg"
DEST="MouseJiggler/Assets.xcassets/AppIcon.appiconset"

# Sizes needed by macOS asset catalog
declare -a SIZES=(16 32 64 128 256 512 1024)

convert_svg() {
  local size=$1
  local out="$DEST/AppIcon-${size}.png"

  if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w "$size" -h "$size" "$SVG" -o "$out"
  elif command -v inkscape &>/dev/null; then
    inkscape --export-type=png --export-width="$size" --export-height="$size" \
             --export-filename="$out" "$SVG" 2>/dev/null
  else
    echo "Error: install librsvg (brew install librsvg) or Inkscape." >&2
    exit 1
  fi

  echo "  Created $out (${size}×${size})"
}

echo "Generating app icons from $SVG …"
for s in "${SIZES[@]}"; do
  convert_svg "$s"
done
echo "Done. All icons written to $DEST"
