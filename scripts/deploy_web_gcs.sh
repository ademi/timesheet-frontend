#!/usr/bin/env bash
# Deploy Flutter web release to GCS + purge Cloudflare entry points.
# See docs/web-deploy-gcs-cloudflare.md
set -euo pipefail

BUCKET="${BUCKET:-app.rostiq.co}"
API_BASE_URL="${API_BASE_URL:-https://api.rostiq.co}"
CF_ZONE_ID="${CF_ZONE_ID:-}"
CF_API_TOKEN="${CF_API_TOKEN:-}"

cd "$(dirname "$0")/.."

flutter pub get
flutter build web \
  --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --base-href=/

gcloud storage rsync build/web "gs://$BUCKET" \
  --recursive \
  --delete-unmatched-destination-objects \
  --cache-control="public, max-age=31536000, immutable"

for f in index.html flutter_bootstrap.js flutter_service_worker.js manifest.json version.json; do
  if [ -f "build/web/$f" ]; then
    gcloud storage objects update "gs://$BUCKET/$f" \
      --cache-control="no-cache, must-revalidate"
  fi
done

if [ -n "$CF_ZONE_ID" ] && [ -n "$CF_API_TOKEN" ]; then
  curl -fsS -X POST \
    "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"files\":[
      \"https://$BUCKET/\",
      \"https://$BUCKET/index.html\",
      \"https://$BUCKET/flutter_bootstrap.js\",
      \"https://$BUCKET/flutter_service_worker.js\"
    ]}" >/dev/null
  echo "Cloudflare cache purged for entry points."
fi

echo "Deployed to https://$BUCKET/ (API: $API_BASE_URL)"
