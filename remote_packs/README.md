# Remote image packs (Cloudflare R2)

Uploads go to bucket `fantasy-color-packs` and are public at:

`https://cdn.schwabenapps.com`

## Folder layout (local, before upload)

```
my-pack/
  coloring/
    01.png
  puzzle/
    01.png
```

## One-time setup

```bash
npx wrangler login
npx wrangler whoami
```

## Upload a pack

```bash
python3 scripts/upload_r2_pack.py \
  --pack-id halloween-2026 \
  --title "Halloween 2026" \
  --source ~/Desktop/pfad/zum/ordner \
  --as-coloring \
  --starts-at 2026-09-15 \
  --ends-at 2026-11-02
```

Images already in the app bundle (`coloring_source_map.json` / `puzzle_images/`) are **skipped** (no duplicates).

Always uses Wrangler `--remote`.

Dry run:

```bash
python3 scripts/upload_r2_pack.py ... --dry-run
```

## Manifest

`https://cdn.schwabenapps.com/manifest.json`

Packs may include `starts_at` / `ends_at` so the app shows them as event hubs (front while active, back after end).
