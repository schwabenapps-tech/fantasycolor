#!/usr/bin/env python3
"""Sync Desktop › fantasycolor_puzzle → assets/puzzle_images.

Schreibweise: lowercase, Leerzeichen/Sonderzeichen → `_`.
Schreibt assets/puzzle_invalidate_ids.json (entfernte + geänderte IDs).
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = Path.home() / "Desktop/fantasycolor_puzzle"
DEST = ROOT / "assets/puzzle_images"
EXTS = {".png", ".jpg", ".jpeg"}


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def asset_filename(src_name: str) -> str:
    """Lowercase; Bindestriche behalten; Leerzeichen/Punkte/Kommas → `_`."""
    stem, ext = Path(src_name).stem, Path(src_name).suffix.lower()
    if ext == ".jpeg":
        ext = ".jpg"
    stem = re.sub(r"[^a-z0-9\-]+", "_", stem.lower())
    stem = re.sub(r"_+", "_", stem).strip("_")
    return f"{stem}{ext}"


def page_id(filename: str) -> str:
    """Gleiche Logik wie ColoringPage.fromAssetPath (jpg-Endung bleibt in der ID)."""
    lower = filename.lower()
    if lower.endswith(".png") or lower.endswith(".svg"):
        return filename[: filename.rfind(".")]
    return filename


def main() -> int:
    if not SRC.is_dir():
        print(f"Missing source folder: {SRC}", file=sys.stderr)
        return 1

    sources = [
        p
        for p in SRC.iterdir()
        if p.is_file() and p.suffix.lower() in EXTS and not p.name.startswith(".")
    ]
    if not sources:
        print("No images in source folder", file=sys.stderr)
        return 1

    DEST.mkdir(parents=True, exist_ok=True)
    wanted: dict[str, Path] = {}
    for src in sources:
        name = asset_filename(src.name)
        if name in wanted:
            print(f"Name collision: {src.name} and {wanted[name].name} → {name}", file=sys.stderr)
            return 1
        wanted[name] = src

    changed_ids: list[str] = []

    for name, src in sorted(wanted.items()):
        out = DEST / name
        new_h = md5(src)
        old_h = md5(out) if out.exists() else None
        if old_h != new_h:
            shutil.copy2(src, out)
            changed_ids.append(page_id(name))
            print(f"UPDATED {name} <- {src.name}")
        else:
            print(f"same    {name}")

    for p in list(DEST.iterdir()):
        if not p.is_file() or p.suffix.lower() not in EXTS:
            continue
        if p.name not in wanted:
            changed_ids.append(page_id(p.name))
            print(f"DELETE  {p.name}")
            p.unlink()

    # stabile, einzigartige Liste
    uniq = sorted(dict.fromkeys(changed_ids))
    (ROOT / "assets/puzzle_invalidate_ids.json").write_text(
        json.dumps(uniq, indent=2) + "\n", encoding="utf-8"
    )
    print(f"\nInvalidate IDs ({len(uniq)}): {uniq}")
    print(f"Total puzzle images: {len(wanted)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
