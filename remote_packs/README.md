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

### Ausmalbilder nachliefern (mit Sternen-Sperre)

Ausmalbilder dauern länger — neue Dateien später hochladen. Die App liest aus dem Manifest, was **neu** ist (14 Tage Badge, außer Event-Packs) und ob Motive **gesperrt** oder **frei** sind:

```bash
python3 scripts/upload_r2_pack.py \
  --pack-id winter-coloring-extra \
  --title "Merry Christmas" \
  --source ~/Desktop/neue-ausmalbilder \
  --as-coloring \
  --starts-at 2026-11-15 \
  --ends-at 2027-01-06 \
  --coloring-cost 85 \
  --coloring-event-cost 40 \
  --free besonders_niedliches_motiv.png
```

### Silvester-Ausmalbilder (Extra-Boxen am 31.12.)

Pack-ID **muss** `silvester` enthalten. Jede heruntergeladene PNG wird am Silvester-Tag als **zusätzliche Geschenkbox** gezeigt (neben Sticker + den 2 Bundle-Puzzles). Bis die Box geöffnet wurde, bleiben die Motive unsichtbar/gesperrt.

```bash
python3 scripts/upload_r2_pack.py \
  --pack-id silvester-2026 \
  --title "Silvester Surprise" \
  --source ~/Desktop/silvester-ausmalbilder \
  --as-coloring \
  --starts-at 2026-12-31 \
  --ends-at 2027-01-06
```

Weitere Motive später nachladen: gleichen `--pack-id` erneut mit dem Ordner (Merge). Upload idealerweise **bevor** Nutzer die Silvester-Box öffnen.

Optional fein pro Datei: `--locks locks.json`

```json
{
  "coloring": {
    "fee_extra_01.png": { "cost": 85, "event_cost": 35 },
    "fee_extra_02.png": { "cost": 0 }
  }
}
```

`cost: 0` = frei. Während `starts_at`…`ends_at` gilt `event_cost`, danach der Normalpreis.

Images already in the app bundle are **skipped** (no duplicates):

- Coloring: `assets/coloring_pages/*` **and** `coloring_source_map.json` keys+values
- Puzzle: `assets/puzzle_images/*`
- Stickers: `assets/stickers/*`

**Wichtig:** CDN kann Bundle-Bilder **nicht ersetzen**. Gleicher Stem (`fee_clean_50.png`) wird in der App verworfen — sichtbare Änderungen brauchen ein Store-Update mit neuem Asset. CDN nur für **neue** Dateinamen, die noch nicht im Bundle liegen.

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

Ohne Katalog vergibt das Script IDs wie `remote_fairy-stickers_<dateiname>`. Dateinamen werden beim Upload zu ASCII-Slugs normalisiert (keine Spaces/Kommas/Umlaute in CDN-Keys).

Inkrementelle Uploads **mergen** mit dem bestehenden Pack (Katalog + Manifest). Nur mit `--cleanup-stale` werden alte Pack-Dateien gelöscht.

Nach dem Upload lädt die App beim nächsten Start das Manifest und merged die Stickers ins Album / Daily Gift — **neue** Remote-Stickers erscheinen vorn im Album.

## Manifest

`https://cdn.schwabenapps.com/manifest.json`

Packs may include `starts_at` / `ends_at` so the app shows them as event hubs (front while active, back after end).

## Force Update (app_config.json)

**Wichtig:** Ohne diese Datei auf dem CDN (HTTP 404) ist Force Update wirkungslos.
Die App fail-opent bewusst — Nutzer werden nicht ausgesperrt, wenn die Config fehlt.

Beim App-Start lädt die App:

`https://cdn.schwabenapps.com/app_config.json`

Wenn die installierte Version (aus dem Store-Build via `PackageInfo`) **kleiner**
als `min_version` / `minVersion` ist, erscheint ein nicht schließbares Overlay
mit Store-Button.

Lokale Vorlage: `remote_packs/app_config.json`

Hochladen:

```bash
npx wrangler r2 object put fantasy-color-packs/app_config.json \
  --file=remote_packs/app_config.json \
  --content-type=application/json \
  --remote
```

Danach prüfen: `curl -sI https://cdn.schwabenapps.com/app_config.json` → muss `200` sein.

Beispiel Force Update ab Version 1.2.0:

```json
{
  "min_version": "1.2.0",
  "message": "Please update Fairy Fantasy Color to continue."
}
```

`min_version` bewusst niedrig lassen (`1.0.0`), solange kein Update erzwungen werden soll.
