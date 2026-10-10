#!/usr/bin/env python3
"""Sync vereinfachte Ausmalbilder → assets/print_templates.

Quellen (nur einfache Motive, inkl. Halloween):
- ~/Desktop/bilder_fantasycolor/einfachere bilder
- ~/Desktop/fantasycolor_event_halloween/halloween ausmalbilder

Schwierige Root-Motive aus bilder_fantasycolor werden nicht übernommen.
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
    Path.home() / "Desktop/bilder_fantasycolor/einfachere bilder",
    Path.home() / "Desktop/fantasycolor_event_halloween/halloween ausmalbilder",
]
DEST = ROOT / "assets/print_templates"
HASH_PATH = ROOT / "assets/print_source_hashes.json"
EXTS = {".png", ".jpg", ".jpeg"}


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def asset_filename(src_name: str) -> str:
    stem, ext = Path(src_name).stem, Path(src_name).suffix.lower()
    if ext == ".jpeg":
        ext = ".jpg"
    stem = re.sub(r"[^a-z0-9\-]+", "_", stem.lower())
    stem = re.sub(r"_+", "_", stem).strip("_")
    return f"{stem}{ext}"


def main() -> int:
    sources: list[Path] = []
    for folder in SRC_DIRS:
        if not folder.is_dir():
            print(f"Missing source folder: {folder}", file=sys.stderr)
            continue
        for p in folder.iterdir():
            if not p.is_file() or p.suffix.lower() not in EXTS:
                continue
            if p.name.startswith("."):
                continue
            sources.append(p)

    if not sources:
        print("No print templates on desktop", file=sys.stderr)
        return 1

    DEST.mkdir(parents=True, exist_ok=True)
    wanted: dict[str, Path] = {}
    for src in sources:
        name = asset_filename(src.name)
        if name in wanted:
            print(f"Name collision: {src.name} → {name}", file=sys.stderr)
            return 1
        wanted[name] = src

    prev_hashes: dict[str, str] = {}
    if HASH_PATH.exists():
        try:
            raw = json.loads(HASH_PATH.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                prev_hashes = {str(k): str(v) for k, v in raw.items()}
        except json.JSONDecodeError:
            prev_hashes = {}

    hashes: dict[str, str] = {}
    changed = 0
    for name, src in sorted(wanted.items()):
        out = DEST / name
        new_h = md5(src)
        old_h = prev_hashes.get(name)
        if old_h == new_h and out.exists():
            print(f"same    {name}")
        elif (
            old_h is not None
            and out.exists()
            and old_h == md5(out)
            and src.stat().st_mtime <= out.stat().st_mtime + 1
        ):
            print(f"same    {name} (hash migrate)")
        else:
            shutil.copy2(src, out)
            changed += 1
            print(f"UPDATED {name} <- {src.name}")
        hashes[name] = new_h

    for p in list(DEST.iterdir()):
        if not p.is_file() or p.suffix.lower() not in EXTS:
            continue
        if p.name not in wanted:
            print(f"DELETE  {p.name}")
            p.unlink()

    HASH_PATH.write_text(
        json.dumps(hashes, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"Total print templates: {len(wanted)} (updated {changed})")
    subprocess.check_call([sys.executable, str(ROOT / "scripts/generate_asset_manifest.py")])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
