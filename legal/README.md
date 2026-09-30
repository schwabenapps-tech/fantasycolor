# Legal texts (Fantasy Color)

Hosted live on Cloudflare R2 / CDN:

| Page | URL |
|---|---|
| Privacy | https://cdn.schwabenapps.com/fantasy-color/legal/privacy.html |
| Terms | https://cdn.schwabenapps.com/fantasy-color/legal/terms.html |

Local source: `legal/site/` (logo + app name header, EN/DE toggle).

Re-upload after edits:

```bash
bash scripts/upload_legal_site.sh
```

## International review notes (draft)

Covered in the hosted Privacy Policy:

- EU/UK GDPR legal bases + data-subject rights + supervisory authority complaint
- COPPA / kids & families framing + parental contact
- CCPA/CPRA “do not sell”
- International transfers / processor list (Firebase, AdMob, Cloudflare)
- No automated decision-making of significant effect
- On-device data vs analytics/crash/ads/support categories
- Google UMP for European disclosures; kids = under age of consent; Settings → Ad privacy choices

These are practical store-ready drafts, not formal legal advice. Have a lawyer review before large markets if needed.

## AdMob GDPR message (required in console)

App code already runs UMP before ads. You still need a message in AdMob:

1. AdMob → **Privacy & messaging**
2. Create a **European regulations (GDPR)** message
3. Publish and **assign it to Fantasy Color** (Android + iOS apps)
4. Keep ads **child-directed / G-rated**; the app already sets TFUA + non-personalized requests

Until the message is published and the app has real AdMob IDs, UMP may do little in production outside test setups.

## Store listing

Use the Privacy URL above in Google Play Console and App Store Connect.
