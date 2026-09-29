# fantasy_color

Fantasy Color — eine Mal- und Ausmal-App (Flutter).

## Cloudflare R2 (Bild-Packs hochladen)

| | |
|---|---|
| Bucket | `fantasy-color-packs` |
| Öffentliche URL | `https://cdn.schwabenapps.com` |
| Manifest | `https://cdn.schwabenapps.com/manifest.json` |

Die App lädt neue Packs beim Start automatisch. Motive, die schon im Bundle sind, werden weder hochgeladen noch doppelt angezeigt. Events erscheinen in Ausmalen/Puzzle als Hub vorne; nach Event-Ende rutschen sie nach hinten.

```bash
python3 scripts/upload_r2_pack.py \
  --pack-id mein-event \
  --title "Mein Event" \
  --source ~/Desktop/ordner \
  --as-coloring \
  --starts-at 2026-09-15 \
  --ends-at 2026-11-02
```

Mehr: [remote_packs/README.md](remote_packs/README.md).

## Getting Started

```bash
flutter pub get
flutter run
```

Flutter-Docs: [docs.flutter.dev](https://docs.flutter.dev/).
