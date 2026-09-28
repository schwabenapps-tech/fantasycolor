#!/usr/bin/env python3
"""Sync Desktop-Ausmalbilder → assets/coloring_pages (stabile IDs).

Quellen:
- ~/Desktop/bilder_fantasycolor/einfachere bilder
- ~/Desktop/fantasycolor_event_halloween/halloween ausmalbilder

Schreibt außerdem:
- assets/coloring_asset_hashes.json
- assets/coloring_invalidate_ids.json  (nur geänderte IDs → Fortschritt löschen)
- assets/coloring_source_map.json     (fee_clean_XX → Quelldateiname)
"""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC_DIRS = [
    Path.home() / "Desktop/bilder_fantasycolor/einfachere bilder",
    Path.home() / "Desktop/fantasycolor_event_halloween/halloween ausmalbilder",
]
DEST = ROOT / "assets/coloring_pages"
MAP_PATH = ROOT / "assets/coloring_source_map.json"

# Reihenfolge = fee_clean_01 … (nicht nach mtime neu nummerieren!)
# Neue Desktop-Dateien werden unten angehängt; entfernte fliegen raus.
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
    # Neu ab 19. Sept.
    "ChatGPT Image 19. Sept. 2026, 11_00_50.png",
    "ChatGPT Image 19. Sept. 2026, 11_04_45.png",
    "ChatGPT Image 19. Sept. 2026, 11_10_24.png",
    "ChatGPT Image 19. Sept. 2026, 11_15_58.png",
    "ChatGPT Image 19. Sept. 2026, 11_21_15.png",
    "ChatGPT Image 19. Sept. 2026, 11_29_36.png",
    # Halloween Ausmalbilder
    "227F10E2-C21E-43BE-8187-A571E6BF30A4.png",
    "ChatGPT Image 24. Sept. 2026, 11_08_41.png",
    "ChatGPT-Bild 26. Sept. 2026, 23_14_56.png",
    "ChatGPT-Bild 26. Sept. 2026, 23_53_27.png",
    "ChatGPT-Bild 27. Sept. 2026, 00_06_29.png",
    "ChatGPT-Bild 27. Sept. 2026, 00_51_02.png",
]


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def collect_desktop() -> dict[str, Path]:
    found: dict[str, Path] = {}
    for folder in SRC_DIRS:
        if not folder.is_dir():
            print(f"Missing source folder: {folder}", file=sys.stderr)
            continue
        for f in folder.glob("*.png"):
            if f.name in found:
                print(
                    f"Name collision: {f} and {found[f.name]}",
                    file=sys.stderr,
                )
                raise SystemExit(1)
            found[f.name] = f
    return found


def resolve_order(desk: dict[str, Path]) -> list[str]:
    """ORDER bereinigen + neue Desktop-Dateien anhängen."""
    kept = [n for n in ORDER if n in desk]
    known = set(kept)
    extras = sorted(n for n in desk if n not in known)
    if extras:
        print("Appending new desktop files:")
        for n in extras:
            print(f"  + {n}")
    removed = [n for n in ORDER if n not in desk]
    if removed:
        print("Removed (not on desktop anymore):")
        for n in removed:
            print(f"  - {n}")
    return kept + extras


def main() -> int:
    desk = collect_desktop()
    if not desk:
        print("No coloring images found on desktop", file=sys.stderr)
        return 1

    order = resolve_order(desk)
    DEST.mkdir(parents=True, exist_ok=True)
    changed: list[str] = []
    hashes: dict[str, str] = {}
    source_map: dict[str, str] = {}

    for i, name in enumerate(order, 1):
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
        source_map[out.stem] = name

    for p in list(DEST.glob("fee_clean_*.png")):
        num = int(p.stem.split("_")[-1])
        if num > len(order):
            print(f"DELETE  {p.name}")
            changed.append(p.stem)
            p.unlink()

    (ROOT / "assets/coloring_asset_hashes.json").write_text(
        json.dumps(hashes, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (ROOT / "assets/coloring_invalidate_ids.json").write_text(
        json.dumps(changed, indent=2) + "\n", encoding="utf-8"
    )
    MAP_PATH.write_text(
        json.dumps(source_map, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    halloween_ids = [
        f"fee_clean_{i:02d}"
        for i, name in enumerate(order, 1)
        if "halloween" in str(desk[name].parent).lower()
    ]
    # Neueste zuerst (höhere fee_clean-Nummer).
    halloween_ids = list(reversed(halloween_ids))
    featured_ids = list(
        reversed([f"fee_clean_{i:02d}" for i in range(1, len(order) + 1) if i >= 27])
    )
    # Halloween vor den übrigen neuen Motiven.
    hall_set = set(halloween_ids)
    featured_ids = [i for i in featured_ids if i in hall_set] + [
        i for i in featured_ids if i not in hall_set
    ]
    _merge_event_tags(
        halloween_coloring=halloween_ids,
        featured_coloring=featured_ids,
    )

    print(f"\nChanged IDs ({len(changed)}): {changed}")
    print(f"Total coloring pages: {len(order)}")
    print(f"Halloween coloring: {halloween_ids}")

    subprocess.check_call([sys.executable, str(ROOT / "scripts/generate_asset_manifest.py")])
    return 0


def _merge_event_tags(
    *,
    halloween_coloring: list[str] | None = None,
    featured_coloring: list[str] | None = None,
    halloween_puzzle: list[str] | None = None,
    featured_puzzle: list[str] | None = None,
) -> None:
    path = ROOT / "assets/event_tags.json"
    data: dict[str, object] = {}
    if path.exists():
        data = json.loads(path.read_text(encoding="utf-8"))
    if halloween_coloring is not None:
        data["halloween_coloring"] = halloween_coloring
    if featured_coloring is not None:
        data["featured_coloring"] = featured_coloring
    if halloween_puzzle is not None:
        data["halloween_puzzle"] = halloween_puzzle
    if featured_puzzle is not None:
        data["featured_puzzle"] = featured_puzzle
    path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    raise SystemExit(main())
