#!/usr/bin/env bash
# Build Flutter web and deploy to Cloudflare Worker `app_rostiq`.
# See docs/web-deploy-cloudflare-workers.md
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-https://api.rostiq.co}"
FLUTTER_PIN_FILE="$(dirname "$0")/../.flutter-version"

cd "$(dirname "$0")/.."

if [[ -f "$FLUTTER_PIN_FILE" ]]; then
  expected="$(tr -d '[:space:]' < "$FLUTTER_PIN_FILE")"
  actual="$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')"
  if [[ -n "$actual" && "$actual" != "$expected" ]]; then
    echo "Warning: local Flutter is $actual; CI pins $expected (.flutter-version)." >&2
  fi
fi

flutter pub get
flutter build web \
  --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --base-href=/

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "CLOUDFLARE_API_TOKEN is required (CLOUDFLARE_ACCOUNT_ID optional if set in wrangler.toml)." >&2
  exit 1
fi

npx --yes wrangler@4 deploy

echo "Deployed to https://app.rostiq.co/"
