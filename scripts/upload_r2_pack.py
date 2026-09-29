#!/usr/bin/env python3
"""Upload a local image pack to Cloudflare R2 (fantasy-color-packs).

Always talks to the *remote* bucket (--remote). Local Miniflare storage is never used.

Skips images already present in the app bundle (coloring_source_map / puzzle_images)
so duplicates are never uploaded.

Expected source layout:

  my-pack/
    coloring/   # optional PNGs
    puzzle/     # optional PNGs

Usage:

  python3 scripts/upload_r2_pack.py \\
    --pack-id halloween-2026 \\
    --title "Halloween 2026" \\
    --source ~/Desktop/.../ordner \\
    --as-coloring \\
    --starts-at 2026-09-15 \\
    --ends-at 2026-11-02
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUCKET = "fantasy-color-packs"
CDN_BASE = "https://cdn.schwabenapps.com"
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp"}
SOURCE_MAP = ROOT / "assets/coloring_source_map.json"
PUZZLE_DIR = ROOT / "assets/puzzle_images"


def normalize_name(name: str) -> str:
    """Match Source-Map and R2 keys across spaces/underscores."""
    stem = Path(name).name
    stem = re.sub(r"\.(png|jpg|jpeg|webp)$", "", stem, flags=re.IGNORECASE)
    stem = stem.lower().replace(" ", "_").replace("-", "_")
    stem = re.sub(r"_+", "_", stem).strip("_")
    return stem


def run_wrangler(args: list[str]) -> None:
    cmd = ["npx", "--yes", "wrangler", *args]
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True)


def content_type_for(path: Path) -> str:
    guessed, _ = mimetypes.guess_type(str(path))
    if guessed:
        return guessed
    if path.suffix.lower() == ".png":
        return "image/png"
    return "application/octet-stream"


def put_object(key: str, local: Path) -> None:
    run_wrangler(
        [
            "r2",
            "object",
            "put",
            f"{BUCKET}/{key}",
            f"--file={local}",
            f"--content-type={content_type_for(local)}",
            "--remote",
        ]
    )


def delete_object(key: str) -> None:
    run_wrangler(
        [
            "r2",
            "object",
            "delete",
            f"{BUCKET}/{key}",
            "--remote",
        ]
    )


def fetch_remote_manifest() -> dict:
    with tempfile.TemporaryDirectory() as tmp:
        dest = Path(tmp) / "manifest.json"
        try:
            run_wrangler(
                [
                    "r2",
                    "object",
                    "get",
                    f"{BUCKET}/manifest.json",
                    f"--file={dest}",
                    "--remote",
                ]
            )
        except subprocess.CalledProcessError:
            print("No remote manifest yet — starting fresh.")
            return {"version": 1, "packs": []}
        data = json.loads(dest.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return {"version": 1, "packs": []}
        data.setdefault("version", 1)
        data.setdefault("packs", [])
        return data


def load_bundle_names() -> tuple[set[str], set[str]]:
    coloring: set[str] = set()
    if SOURCE_MAP.is_file():
        data = json.loads(SOURCE_MAP.read_text(encoding="utf-8"))
        for value in data.values():
            coloring.add(normalize_name(str(value)))
    puzzle: set[str] = set()
    if PUZZLE_DIR.is_dir():
        for path in PUZZLE_DIR.iterdir():
            if path.is_file() and path.suffix.lower() in IMAGE_EXTS:
                puzzle.add(normalize_name(path.name))
    return coloring, puzzle


def collect_images(folder: Path) -> list[Path]:
    if not folder.is_dir():
        return []
    return [
        p
        for p in sorted(folder.iterdir())
        if p.is_file() and p.suffix.lower() in IMAGE_EXTS and not p.name.startswith(".")
    ]


def resolve_sections(source: Path, as_coloring: bool) -> dict[str, list[Path]]:
    sections: dict[str, list[Path]] = {"coloring": [], "puzzle": []}
    coloring_dir = source / "coloring"
    puzzle_dir = source / "puzzle"

    if coloring_dir.is_dir() or puzzle_dir.is_dir():
        sections["coloring"] = collect_images(coloring_dir)
        sections["puzzle"] = collect_images(puzzle_dir)
        return sections

    if as_coloring:
        sections["coloring"] = collect_images(source)
        return sections

    raise SystemExit(
        f"Expected {source}/coloring and/or {source}/puzzle, "
        "or pass --as-coloring to treat the folder as coloring images."
    )


def sanitize_name(name: str) -> str:
    return name.replace(" ", "_")


def filter_duplicates(
    sections: dict[str, list[Path]],
) -> tuple[dict[str, list[Path]], list[str]]:
    coloring_bundle, puzzle_bundle = load_bundle_names()
    kept: dict[str, list[Path]] = {"coloring": [], "puzzle": []}
    skipped: list[str] = []
    for section, files in sections.items():
        bundle = coloring_bundle if section == "coloring" else puzzle_bundle
        for path in files:
            key = normalize_name(path.name)
            if key in bundle:
                skipped.append(f"{section}/{path.name}")
                print(f"  skipped duplicate: {section}/{path.name}")
            else:
                kept[section].append(path)
    return kept, skipped


def upload_pack(pack_id: str, sections: dict[str, list[Path]]) -> list[str]:
    uploaded: list[str] = []
    for section, files in sections.items():
        for path in files:
            key = f"packs/{pack_id}/{section}/{sanitize_name(path.name)}"
            put_object(key, path)
            uploaded.append(key)
            print(f"  OK  {CDN_BASE}/{key}")
    return uploaded


def upsert_manifest(
    manifest: dict,
    pack_id: str,
    title: str,
    files: list[str],
    starts_at: str | None,
    ends_at: str | None,
) -> dict:
    packs = list(manifest.get("packs") or [])
    # Drop empty packs and rebuild this pack.
    packs = [p for p in packs if p.get("id") != pack_id and p.get("files")]
    if files:
        entry: dict = {
            "id": pack_id,
            "version": 1,
            "title": title,
            "files": files,
        }
        existing_version = 0
        for old in manifest.get("packs") or []:
            if old.get("id") == pack_id:
                existing_version = int(old.get("version") or 0)
                break
        entry["version"] = existing_version + 1 if existing_version else 1
        if starts_at:
            entry["starts_at"] = starts_at
        if ends_at:
            entry["ends_at"] = ends_at
        packs.append(entry)
    manifest["packs"] = packs
    manifest["version"] = int(manifest.get("version") or 0) + 1
    return manifest


def cleanup_pack_objects(pack_id: str, keep: set[str]) -> None:
    """Best-effort: remove known old halloween keys not in keep."""
    # Wrangler has no simple list in all versions — delete previous halloween files
    # from the last known manifest instead.
    manifest = fetch_remote_manifest()
    for pack in manifest.get("packs") or []:
        if pack.get("id") != pack_id:
            continue
        for key in pack.get("files") or []:
            if key not in keep:
                try:
                    delete_object(key)
                    print(f"  deleted stale: {key}")
                except subprocess.CalledProcessError:
                    print(f"  warn: could not delete {key}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack-id", required=True, help="Stable pack id, e.g. halloween-2026")
    parser.add_argument("--title", required=True, help="Display title for the pack")
    parser.add_argument(
        "--source",
        required=True,
        type=Path,
        help="Local folder with coloring/ and/or puzzle/, or flat images with --as-coloring",
    )
    parser.add_argument(
        "--as-coloring",
        action="store_true",
        help="Treat --source as a flat folder of coloring images",
    )
    parser.add_argument("--starts-at", default=None, help="Event start YYYY-MM-DD")
    parser.add_argument("--ends-at", default=None, help="Event end YYYY-MM-DD")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List files that would upload; do not call Wrangler",
    )
    parser.add_argument(
        "--cleanup-stale",
        action="store_true",
        help="Delete previous remote files for this pack that are no longer uploaded",
    )
    args = parser.parse_args()

    source = args.source.expanduser().resolve()
    if not source.is_dir():
        raise SystemExit(f"Source folder not found: {source}")

    raw_sections = resolve_sections(source, args.as_coloring)
    sections, skipped = filter_duplicates(raw_sections)
    planned: list[str] = []
    for section, files in sections.items():
        for path in files:
            planned.append(
                f"packs/{args.pack_id}/{section}/{sanitize_name(path.name)}"
            )

    print(f"Pack: {args.pack_id} ({args.title})")
    print(f"Source: {source}")
    print(f"New files: {len(planned)}  skipped duplicates: {len(skipped)}")
    for key in planned:
        print(f"  → {CDN_BASE}/{key}")

    if args.dry_run:
        print("Dry run — nothing uploaded.")
        return 0

    if args.cleanup_stale:
        cleanup_pack_objects(args.pack_id, set(planned))

    files = upload_pack(args.pack_id, sections) if planned else []
    if not planned and not skipped:
        raise SystemExit(f"No images found under {source}")

    manifest = fetch_remote_manifest()
    # If everything was duplicate, remove empty pack from CDN.
    if args.cleanup_stale or not files:
        for pack in list(manifest.get("packs") or []):
            if pack.get("id") == args.pack_id:
                for key in pack.get("files") or []:
                    if key not in files:
                        try:
                            delete_object(key)
                            print(f"  deleted stale: {key}")
                        except subprocess.CalledProcessError:
                            pass

    manifest = upsert_manifest(
        manifest,
        args.pack_id,
        args.title,
        files,
        args.starts_at,
        args.ends_at,
    )

    with tempfile.TemporaryDirectory() as tmp:
        local_manifest = Path(tmp) / "manifest.json"
        local_manifest.write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        put_object("manifest.json", local_manifest)

    print()
    print("Done.")
    print(f"Manifest: {CDN_BASE}/manifest.json")
    if files:
        pack = next(p for p in manifest["packs"] if p["id"] == args.pack_id)
        print(f"Pack version: {pack['version']}  files: {len(files)}")
    else:
        print("Pack not listed (all files were bundle duplicates).")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(f"Wrangler failed with exit code {exc.returncode}", file=sys.stderr)
        raise SystemExit(exc.returncode)
