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
  stickers/          # optional — new album stickers without app update
    catalog.json     # optional; auto-generated if missing
    fairy_new.png
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

Images already in the app bundle (`coloring_source_map.json` / `puzzle_images/` / `assets/stickers/`) are **skipped** (no duplicates).

Always uses Wrangler `--remote`.

Dry run:

```bash
python3 scripts/upload_r2_pack.py ... --dry-run
```

## Stickers updaten (ohne App-Store-Update)

Flat-Ordner mit neuen PNGs (optional eigene `catalog.json`):

```bash
python3 scripts/upload_r2_pack.py \
  --pack-id fairy-stickers \
  --title "Fairy Stickers" \
  --source ~/Desktop/neue-stickers \
  --as-stickers
```

`catalog.json` Format:

```json
{
  "stickers": [
    {
      "id": "sticker_44",
      "asset": "meine_fee.png",
      "coloringId": "fee_clean_44"
    }
  ]
}
```

Ohne Katalog vergibt das Script IDs wie `remote_fairy-stickers_<dateiname>`. Nach dem Upload lädt die App beim nächsten Start das Manifest und merged die Stickers ins Album / Daily Gift.

## Manifest

`https://cdn.schwabenapps.com/manifest.json`

Packs may include `starts_at` / `ends_at` so the app shows them as event hubs (front while active, back after end).
