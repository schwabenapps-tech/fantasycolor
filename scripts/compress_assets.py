#!/usr/bin/env python3
"""Komprimiert Asset-PNGs/JPEGs (Palette + Optimize). Dimensionen bleiben gleich."""

from __future__ import annotations

import glob
import os
import sys

from PIL import Image

FOLDERS = [
    "assets/coloring_pages",
    "assets/puzzle_images",
    "assets/images",
]


def compress_png(path: str) -> tuple[str, int, int, str | None]:
    before = os.path.getsize(path)
    if before < 50_000:
        return "skip", before, before, "tiny"

    try:
        im = Image.open(path)
        im.load()
    except Exception as exc:  # noqa: BLE001
        return "fail", before, before, str(exc)

    tmp = path + ".compress_tmp.png"
    try:
        if im.mode not in ("RGB", "RGBA", "P", "L"):
            im = im.convert("RGBA")

        if im.mode == "P" and "transparency" in im.info:
            im.save(tmp, format="PNG", optimize=True, compress_level=9)
        else:
            if im.mode == "L":
                im = im.convert("RGB")
            if im.mode == "RGBA":
                q = im.quantize(colors=256, method=Image.Quantize.FASTOCTREE)
            else:
                q = im.convert("RGB").quantize(
                    colors=256, method=Image.Quantize.MEDIANCUT
                )
            q.save(tmp, format="PNG", optimize=True, compress_level=9)

        after = os.path.getsize(tmp)
        if after >= before:
            Image.open(path).save(tmp, format="PNG", optimize=True, compress_level=9)
            after = os.path.getsize(tmp)

        if after < before:
            os.replace(tmp, path)
            return "ok", before, after, None

        os.remove(tmp)
        return "skip", before, before, "no gain"
    except Exception as exc:  # noqa: BLE001
        if os.path.exists(tmp):
            os.remove(tmp)
        return "fail", before, before, str(exc)


def compress_jpeg(path: str) -> tuple[str, int, int, str | None]:
    before = os.path.getsize(path)
    tmp = path + ".tmp.jpg"
    try:
        im = Image.open(path).convert("RGB")
        im.save(tmp, format="JPEG", quality=82, optimize=True)
        after = os.path.getsize(tmp)
        if after < before:
            os.replace(tmp, path)
            return "ok", before, after, None
        os.remove(tmp)
        return "skip", before, before, "no gain"
    except Exception as exc:  # noqa: BLE001
        if os.path.exists(tmp):
            os.remove(tmp)
        return "fail", before, before, str(exc)


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)

    total_before = total_after = 0
    for folder in FOLDERS:
        paths = sorted(
            p
            for p in glob.glob(folder + "/*")
            if p.lower().endswith((".png", ".jpg", ".jpeg"))
        )
        print(f"\n=== {folder} ({len(paths)}) ===")
        for path in paths:
            if path.lower().endswith((".jpg", ".jpeg")):
                status, before, after, err = compress_jpeg(path)
            else:
                status, before, after, err = compress_png(path)
            total_before += before
            total_after += after
            name = os.path.basename(path)
            if status == "ok":
                pct = 100 * (1 - after / before)
                print(
                    f"  OK  {before/1024/1024:.2f}->{after/1024/1024:.2f} MB "
                    f"({pct:.0f}%)  {name}"
                )
            elif status == "fail":
                print(f"  FAIL {name}: {err}")

    saved = (total_before - total_after) / 1024 / 1024
    print(
        f"\nTOTAL {total_before/1024/1024:.1f} -> "
        f"{total_after/1024/1024:.1f} MB  saved {saved:.1f} MB"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
