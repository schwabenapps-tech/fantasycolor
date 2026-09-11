#!/usr/bin/env python3
"""Sync Desktop › einfachere bilder → assets/coloring_pages (stabile IDs).

Schreibt außerdem:
- assets/coloring_asset_hashes.json
- assets/coloring_invalidate_ids.json  (nur geänderte IDs → Fortschritt löschen)
"""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = Path.home() / "Desktop/bilder_fantasycolor/einfachere bilder"
DEST = ROOT / "assets/coloring_pages"

# Reihenfolge = fee_clean_01 … (nicht nach mtime neu nummerieren!)
ORDER = [
    "ChatGPT Image 5. Sept. 2026, 21_43_42.png",
    "ChatGPT Image 5. Sept. 2026, 22_42_49.png",
    "ChatGPT Image 5. Sept. 2026, 21_40_45.png",
    "wasserfee_vereinfacht.png",
    "ChatGPT Image 5. Sept. 2026, 22_03_54.png",
    "ChatGPT Image 5. Sept. 2026, 22_39_37.png",
    "ChatGPT Image 9. Sept. 2026, 22_19_30.png",
    "ChatGPT Image 9. Sept. 2026, 22_26_35.png",
    "vereinfacht.png",
    "ChatGPT Image 9. Sept. 2026, 22_42_09.png",
    "ChatGPT Image 10. Sept. 2026, 21_17_41.png",
    "ChatGPT Image 10. Sept. 2026, 21_49_51.png",
    "ChatGPT Image 5. Sept. 2026, 22_59_11.png",
    "ChatGPT Image 10. Sept. 2026, 22_00_55.png",
    "ChatGPT Image 10. Sept. 2026, 22_07_36.png",
    "ChatGPT Image 10. Sept. 2026, 22_09_45.png",
    "ChatGPT Image 10. Sept. 2026, 22_35_51.png",
    "ChatGPT Image 10. Sept. 2026, 22_38_35.png",
    "ChatGPT Image 10. Sept. 2026, 22_42_15.png",
    "ChatGPT Image 10. Sept. 2026, 22_50_22.png",
    "ChatGPT Image 10. Sept. 2026, 22_52_23.png",
    "ChatGPT Image 11. Sept. 2026, 21_59_12.png",
    "ChatGPT Image 11. Sept. 2026, 22_04_46.png",
    "ChatGPT Image 11. Sept. 2026, 22_07_20.png",
    "ChatGPT Image 11. Sept. 2026, 22_13_20.png",
    "ChatGPT Image 11. Sept. 2026, 22_15_13.png",
]


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def main() -> int:
    if not SRC.is_dir():
        print(f"Missing source folder: {SRC}", file=sys.stderr)
        return 1

    desk = {f.name: f for f in SRC.glob("*.png")}
    missing = [n for n in ORDER if n not in desk]
    if missing:
        print("Missing on desktop:", *missing, sep="\n  ", file=sys.stderr)
        return 1

    DEST.mkdir(parents=True, exist_ok=True)
    changed: list[str] = []
    hashes: dict[str, str] = {}

    for i, name in enumerate(ORDER, 1):
        out = DEST / f"fee_clean_{i:02d}.png"
        src_f = desk[name]
        new_h = md5(src_f)
        old_h = md5(out) if out.exists() else None
        if old_h != new_h:
            shutil.copy2(src_f, out)
            changed.append(out.stem)
            print(f"UPDATED {out.name} <- {name}")
        else:
            print(f"same    {out.name} <- {name}")
        hashes[out.stem] = new_h

    for p in list(DEST.glob("fee_clean_*.png")):
        num = int(p.stem.split("_")[-1])
        if num > len(ORDER):
            print(f"DELETE  {p.name}")
            changed.append(p.stem)
            p.unlink()

    (ROOT / "assets/coloring_asset_hashes.json").write_text(
        json.dumps(hashes, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (ROOT / "assets/coloring_invalidate_ids.json").write_text(
        json.dumps(changed, indent=2) + "\n", encoding="utf-8"
    )
    print(f"\nChanged IDs ({len(changed)}): {changed}")

    subprocess.check_call([sys.executable, str(ROOT / "scripts/generate_asset_manifest.py")])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
