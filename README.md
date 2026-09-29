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

## Support e-mail (Cloudflare Email Routing)

App address: `fantasycolor@schwabenapps.com`  
Forwards to `schwabenapps@gmail.com` via Cloudflare Email Routing on zone `schwabenapps.com`.

Setup (already configured if the rule exists):

1. Email → Email Routing → **Routing-Regeln**
2. Rule: `fantasycolor` @ `schwabenapps.com` → Send to `schwabenapps@gmail.com`
3. Destination address must be verified under **Zieladressen**

## Legal pages (Privacy / Terms)

| | |
|---|---|
| Privacy | https://cdn.schwabenapps.com/fantasy-color/legal/privacy.html |
| Terms | https://cdn.schwabenapps.com/fantasy-color/legal/terms.html |

Source + re-upload: [legal/README.md](legal/README.md).

## Getting Started

```bash
flutter pub get
flutter run
```

Flutter-Docs: [docs.flutter.dev](https://docs.flutter.dev/).
