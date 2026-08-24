#!/usr/bin/env python3
"""Generiert assets/asset_dimensions.json aus PNG/JPEG-Headern."""

from __future__ import annotations

import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def png_dims(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as f:
        if f.read(8) != b"\x89PNG\r\n\x1a\n":
            return None
        f.read(4)
        if f.read(4) != b"IHDR":
            return None
        w, h = struct.unpack(">II", f.read(8))
        return w, h


def jpeg_dims(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as f:
        if f.read(2) != b"\xff\xd8":
            return None
        while True:
            marker = f.read(2)
            if len(marker) < 2:
                return None
            while marker[0] != 0xFF:
                marker = marker[1:] + f.read(1)
            while marker[0] == 0xFF:
                marker = marker[1:]
                if not marker:
                    marker = f.read(1)
            if marker[0] in (0xC0, 0xC1, 0xC2):
                f.read(3)
                h, w = struct.unpack(">HH", f.read(4))
                return w, h
            length = struct.unpack(">H", f.read(2))[0]
            f.read(length - 2)


def dims_for(path: Path) -> tuple[int, int]:
    lower = path.suffix.lower()
    if lower == ".png":
        size = png_dims(path)
    elif lower in (".jpg", ".jpeg"):
        size = jpeg_dims(path)
    else:
        size = None
    return size or (1408, 768)


def collect(folder: str) -> list[dict[str, object]]:
    base = ROOT / folder
    entries: list[dict[str, object]] = []
    for path in sorted(base.iterdir()):
        if path.suffix.lower() not in {".png", ".jpg", ".jpeg"}:
            continue
        w, h = dims_for(path)
        rel = path.relative_to(ROOT).as_posix()
        entries.append({"path": rel, "width": w, "height": h})
    return entries


def main() -> None:
    manifest = {
        "coloring_pages": collect("assets/coloring_pages"),
        "puzzle_images": collect("assets/puzzle_images"),
    }
    out = ROOT / "assets" / "asset_dimensions.json"
    out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out} ({len(manifest['coloring_pages'])} coloring, {len(manifest['puzzle_images'])} puzzle)")


if __name__ == "__main__":
    main()
