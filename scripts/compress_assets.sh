#!/usr/bin/env bash
# Komprimiert PNG-Assets (benötigt pngquant: brew install pngquant)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v pngquant >/dev/null 2>&1; then
  echo "pngquant nicht gefunden. Installieren mit: brew install pngquant"
  exit 1
fi

compress_dir() {
  local dir="$1"
  echo "Komprimiere $dir ..."
  find "$dir" -name '*.png' -print0 | while IFS= read -r -d '' file; do
    pngquant --force --skip-if-larger --quality=65-90 --ext .png -- "$file"
  done
}

compress_dir "$ROOT/assets/coloring_pages"
compress_dir "$ROOT/assets/puzzle_images"
compress_dir "$ROOT/assets/images"

echo "Fertig. Manifest neu generieren:"
echo "  python3 scripts/generate_asset_manifest.py"
