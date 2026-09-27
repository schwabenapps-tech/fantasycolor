#!/usr/bin/env python3
"""Sync Desktop-Puzzlebilder → assets/puzzle_images.

Quellen:
- ~/Desktop/fantasycolor_puzzle
- ~/Desktop/fantasycolor_event_halloween  (nur Root, nicht „halloween ausmalbilder“)

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
SRC_DIRS = [
    Path.home() / "Desktop/fantasycolor_puzzle",
    Path.home() / "Desktop/fantasycolor_event_halloween",
]
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


def collect_sources() -> list[Path]:
    sources: list[Path] = []
    for folder in SRC_DIRS:
        if not folder.is_dir():
            print(f"Missing source folder: {folder}", file=sys.stderr)
            continue
        for p in folder.iterdir():
            if not p.is_file():
                continue
            if p.suffix.lower() not in EXTS:
                continue
            if p.name.startswith("."):
                continue
            sources.append(p)
    return sources


def main() -> int:
    sources = collect_sources()
    if not sources:
        print("No images in source folders", file=sys.stderr)
        return 1

    DEST.mkdir(parents=True, exist_ok=True)
    wanted: dict[str, Path] = {}
    for src in sources:
        name = asset_filename(src.name)
        if name in wanted:
            print(
                f"Name collision: {src.name} and {wanted[name].name} → {name}",
                file=sys.stderr,
            )
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

    uniq = sorted(dict.fromkeys(changed_ids))
    (ROOT / "assets/puzzle_invalidate_ids.json").write_text(
        json.dumps(uniq, indent=2) + "\n", encoding="utf-8"
    )
    print(f"\nInvalidate IDs ({len(uniq)}): {uniq}")
    print(f"Total puzzle images: {len(wanted)}")

    subprocess.check_call([sys.executable, str(ROOT / "scripts/generate_asset_manifest.py")])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
