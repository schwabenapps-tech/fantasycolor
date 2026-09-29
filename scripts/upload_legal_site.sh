#!/usr/bin/env bash
# Upload Fantasy Color legal pages to Cloudflare R2 (cdn.schwabenapps.com).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$ROOT/legal/site"
BUCKET="fantasy-color-packs"
PREFIX="fantasy-color/legal"
export JAVA_HOME="${JAVA_HOME:-}"

put() {
  local key="$1"
  local file="$2"
  local ctype="$3"
  echo "Uploading $key ($ctype)"
  npx --yes wrangler r2 object put "${BUCKET}/${key}" \
    --file="$file" \
    --content-type="$ctype" \
    --remote
}

put "${PREFIX}/index.html" "$SITE/index.html" "text/html; charset=utf-8"
put "${PREFIX}/privacy.html" "$SITE/privacy.html" "text/html; charset=utf-8"
put "${PREFIX}/terms.html" "$SITE/terms.html" "text/html; charset=utf-8"
put "${PREFIX}/styles.css" "$SITE/styles.css" "text/css; charset=utf-8"
put "${PREFIX}/assets/logo.png" "$SITE/assets/logo.png" "image/png"

echo
echo "Public URLs:"
echo "  https://cdn.schwabenapps.com/${PREFIX}/privacy.html"
echo "  https://cdn.schwabenapps.com/${PREFIX}/terms.html"
