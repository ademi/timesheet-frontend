#!/usr/bin/env bash
# DEPRECATED: GCS + Cloudflare proxy deploy is retired.
# Use ./scripts/deploy_web_workers.sh and docs/web-deploy-cloudflare-workers.md
set -euo pipefail

echo "deploy_web_gcs.sh is deprecated." >&2
echo "Use: ./scripts/deploy_web_workers.sh" >&2
echo "Docs: docs/web-deploy-cloudflare-workers.md" >&2
exit 1
