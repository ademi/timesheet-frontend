# Deploying Flutter web to GCS + Cloudflare

End-to-end guide for serving the **release web build** of `yemen_gate_attendance_app` from a **Google Cloud Storage** bucket with **Cloudflare** as DNS, TLS, cache, and WAF in front.

Backend stays at `https://timesheetbackend.deepdownidea.com`. The web client will be served from a separate hostname (example used here: **`app.deepdownidea.com`**). Pick whatever subdomain you prefer; **the GCS bucket name must equal that hostname.**

---

## 1. Architecture

```
Browser
  │  HTTPS (TLS terminated by Cloudflare)
  ▼
Cloudflare (proxied DNS, cache, WAF)
  │  HTTPS to c.storage.googleapis.com (Host: app.deepdownidea.com)
  ▼
Google Cloud Storage bucket: app.deepdownidea.com
  └─ build/web/* (index.html, main.dart.js, assets/, canvaskit/, …)

Browser → https://timesheetbackend.deepdownidea.com (FastAPI, separate origin)
```

- **GCS** stores the static build, serves it over HTTPS at `https://storage.googleapis.com/<bucket>/...` and (with bucket-name = FQDN) over the virtual-hosted endpoint `c.storage.googleapis.com`.
- **Cloudflare** terminates TLS for `app.deepdownidea.com`, caches assets, and proxies misses to GCS.
- **Backend** is a different origin — CORS must allow the web origin (already wired in `app/main.py`; just add the new origin to `CORS_ORIGINS`).

---

## 2. Prerequisites

| Tool | Notes |
|------|-------|
| Flutter SDK | Same version as the project (`pubspec.yaml`, `^3.7.2`). Verify with `flutter --version`. |
| `gcloud` CLI | Authenticated (`gcloud auth login`) and a project selected (`gcloud config set project <PROJECT_ID>`). |
| `gsutil` | Bundled with `gcloud`. Used for upload + metadata. |
| Cloudflare access | DNS zone for `deepdownidea.com` already managed by Cloudflare. |
| Google Search Console | Required to **verify ownership** of the bucket-name domain (one-off). |

Domain ownership verification (one-off):

1. Open [Search Console](https://search.google.com/search-console) → **Add property** → **Domain** → `deepdownidea.com`.
2. Add the TXT record Google gives you in Cloudflare DNS (DNS-only, gray cloud is fine for TXT).
3. Click **Verify**. Once verified, the same Google account can create buckets named under that domain.

---

## 3. Build the web release

From the workspace root:

```bash
cd frontend
flutter pub get

flutter build web \
  --release \
  --dart-define=API_BASE_URL=https://timesheetbackend.deepdownidea.com \
  --base-href=/
```

Output: `frontend/build/web/`. Key files:

- `index.html` — entry document (small, must **not** be cached long).
- `flutter_bootstrap.js`, `main.dart.js`, `flutter_service_worker.js` — change every build.
- `assets/`, `canvaskit/`, `icons/` — mostly content-addressed; safe to cache long.

**Renderer (optional):** add `--web-renderer canvaskit` (default for desktop browsers) or `html` if you want the smaller HTML renderer. Default is fine for an admin/payroll UI.

**SPA URL strategy:** Flutter web defaults to **hash URLs** (`#/route`) unless you call `setUrlStrategy(PathUrlStrategy())`. With hash routing, no server-side rewrite is needed. If you switch to path strategy, see [§ 8 SPA fallback](#8-spa-fallback-path-url-strategy).

---

## 4. Create and configure the GCS bucket

The **bucket name must equal the public FQDN** so the `Host`-based virtual-hosted endpoint works behind Cloudflare.

```bash
export PROJECT_ID="your-gcp-project"
export BUCKET="app.deepdownidea.com"
export REGION="us-central1"   # pick one close to your users / Cloudflare edge

gcloud config set project "$PROJECT_ID"

gcloud storage buckets create "gs://$BUCKET" \
  --location="$REGION" \
  --uniform-bucket-level-access \
  --public-access-prevention=inherited
```

### 4.1 Make objects publicly readable

With **uniform bucket-level access**, grant `roles/storage.objectViewer` to `allUsers`:

```bash
gcloud storage buckets add-iam-policy-binding "gs://$BUCKET" \
  --member="allUsers" \
  --role="roles/storage.objectViewer"
```

> If your org has **public-access prevention enforced**, this command will fail. Either change the org policy for this bucket or use a **Cloud Load Balancer + signed URLs** instead (out of scope here).

### 4.2 Configure website behaviour

```bash
gcloud storage buckets update "gs://$BUCKET" \
  --web-main-page-suffix=index.html \
  --web-error-page=index.html
```

- `MainPageSuffix=index.html` makes `/` serve `index.html`.
- `NotFoundPage=index.html` makes unknown paths serve `index.html` (returns **HTTP 404** but with the SPA body — see [§ 8](#8-spa-fallback-path-url-strategy) for details and how to upgrade to **HTTP 200** via Cloudflare if you switch to path-style routing).

### 4.3 (Optional) CORS on the bucket

The web client itself is **same-origin** with the bucket (you serve from `app.deepdownidea.com`), so bucket CORS is generally **not** required. Add it only if another origin needs to fetch assets from this bucket:

```json
[
  {
    "origin": ["https://app.deepdownidea.com"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```

```bash
gcloud storage buckets update "gs://$BUCKET" --cors-file=cors.json
```

---

## 5. Upload the build with correct cache headers

Two cache classes:

| Files | `Cache-Control` | Reason |
|-------|-----------------|--------|
| `index.html`, `flutter_bootstrap.js`, `flutter_service_worker.js`, `manifest.json`, `version.json` | `no-cache, must-revalidate` (or `max-age=0`) | Entry points must change on deploy. |
| Everything else (`main.dart.js`, `assets/**`, `canvaskit/**`, `icons/**`, fonts, images) | `public, max-age=31536000, immutable` | Hashed/asset content rarely changes; long cache is safe. |

Upload script (idempotent, sets headers per class):

```bash
cd frontend

# Long-cache: everything
gcloud storage rsync build/web "gs://$BUCKET" \
  --recursive \
  --delete-unmatched-destination-objects \
  --cache-control="public, max-age=31536000, immutable"

# Short-cache: entry files (overwrite headers in place)
for f in index.html flutter_bootstrap.js flutter_service_worker.js manifest.json version.json; do
  if [ -f "build/web/$f" ]; then
    gcloud storage objects update "gs://$BUCKET/$f" \
      --cache-control="no-cache, must-revalidate"
  fi
done
```

> `--delete-unmatched-destination-objects` removes stale files from previous builds. Run **without it first** if you’re uncertain.

Verify:

```bash
gcloud storage objects describe "gs://$BUCKET/index.html" \
  --format="value(cacheControl,contentType)"
```

Your build is now reachable at:

```
https://storage.googleapis.com/app.deepdownidea.com/index.html
```

---

## 6. Point Cloudflare at the bucket

In the Cloudflare dashboard for `deepdownidea.com`:

### 6.1 DNS record

| Type | Name | Target | Proxy |
|------|------|--------|-------|
| `CNAME` | `app` | `c.storage.googleapis.com` | **Proxied (orange cloud)** |

The proxy is essential: it gives you Cloudflare TLS, caching, and hides the GCS origin. Without it (DNS-only) the browser would try a TLS handshake directly with GCS using a cert that doesn’t cover your domain → SSL errors.

> The bucket name **must** equal `app.deepdownidea.com` for the virtual-hosted endpoint to resolve to the right bucket via the `Host` header.

### 6.2 SSL/TLS settings

- **SSL/TLS → Overview:** mode **Full** (Cloudflare → GCS uses HTTPS, but GCS does not present a cert that matches `app.deepdownidea.com`, so **Full (strict) will fail**). Use **Full**, not **Full (strict)**, for this hostname.
- **Edge Certificates:** Universal SSL covers `app.deepdownidea.com` automatically (proxied apex/sub).
- **Always Use HTTPS:** on.
- **Automatic HTTPS Rewrites:** on.

### 6.3 Cache rules

The GCS `Cache-Control` headers we set in §5 are usually enough — Cloudflare will respect them for proxied responses. Add a **Cache Rule** if you want belt-and-braces:

| Match | Action |
|-------|--------|
| Hostname `app.deepdownidea.com` AND URI Path matches `^/(index\.html|flutter_bootstrap\.js|flutter_service_worker\.js|manifest\.json|version\.json|/)$` | **Bypass cache**, or **Edge TTL = 30s** |
| Hostname `app.deepdownidea.com` AND URI Path matches `^/(assets|canvaskit|icons)/` | **Edge TTL = 1 year**, **Browser TTL = respect origin** |

After every deploy, **purge** entry points only:

```text
Caching → Configuration → Custom Purge → URLs:
  https://app.deepdownidea.com/
  https://app.deepdownidea.com/index.html
  https://app.deepdownidea.com/flutter_bootstrap.js
  https://app.deepdownidea.com/flutter_service_worker.js
```

Or via API:

```bash
curl -X POST \
  "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"files":[
    "https://app.deepdownidea.com/",
    "https://app.deepdownidea.com/index.html",
    "https://app.deepdownidea.com/flutter_bootstrap.js",
    "https://app.deepdownidea.com/flutter_service_worker.js"
  ]}'
```

---

## 7. Allow the web origin on the API

The browser will call `https://timesheetbackend.deepdownidea.com` from origin `https://app.deepdownidea.com`. Add it to `CORS_ORIGINS` in `backend/timesheet-backend/app/core/config.py`:

```python
CORS_ORIGINS: list[str] = [
    "http://localhost:3000",
    "http://localhost:8000",
    "https://app.deepdownidea.com",
]
```

Restart the API. The `CORSMiddleware` registered in `app/main.py` handles preflight automatically.

---

## 8. SPA fallback (path URL strategy)

If/when you switch Flutter to **path-based routing** (`setUrlStrategy(PathUrlStrategy())`), users hitting `https://app.deepdownidea.com/payroll/2026-05` directly will hit GCS, miss the object, and fall through to `NotFoundPage=index.html` — **with HTTP status 404**. Flutter loads and routes correctly, but search engines and some monitoring see 404s.

To return **200** for SPA fallback paths, use a Cloudflare **Workers** or **Transform Rule**:

**Transform Rule (rewrite + status):** not directly supported (Transform Rules don’t change status). Use a small Worker:

```js
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const looksLikeAsset = /\.[a-zA-Z0-9]{2,5}$/.test(url.pathname);
    const upstream = await fetch(request);
    if (upstream.status === 404 && !looksLikeAsset) {
      const indexUrl = new URL('/index.html', url.origin);
      const indexResp = await fetch(new Request(indexUrl, request));
      return new Response(indexResp.body, {
        status: 200,
        headers: indexResp.headers,
      });
    }
    return upstream;
  },
};
```

Bind it to `app.deepdownidea.com/*`. Skip this section while you are on hash routing.

---

## 9. Repeatable deploy script

Drop this in `frontend/scripts/deploy_web_gcs.sh` and `chmod +x` it:

```bash
#!/usr/bin/env bash
set -euo pipefail

BUCKET="${BUCKET:-app.deepdownidea.com}"
API_BASE_URL="${API_BASE_URL:-https://timesheetbackend.deepdownidea.com}"
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

echo "Deployed to https://$BUCKET/"
```

Usage:

```bash
BUCKET=app.deepdownidea.com \
CF_ZONE_ID=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
CF_API_TOKEN=cf_xxx \
./scripts/deploy_web_gcs.sh
```

The Cloudflare API token needs `Zone → Cache Purge → Purge` on this zone only.

---

## 10. Verify

```bash
# DNS resolves through Cloudflare
dig +short app.deepdownidea.com

# TLS works and content is the new build
curl -I https://app.deepdownidea.com/
curl -I https://app.deepdownidea.com/main.dart.js

# Backend reachable from the new origin (preflight)
curl -I -X OPTIONS https://timesheetbackend.deepdownidea.com/v1/auth/login \
  -H "Origin: https://app.deepdownidea.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type"
```

You should see:

- `HTTP/2 200` from Cloudflare with `cf-cache-status` headers.
- `access-control-allow-origin: https://app.deepdownidea.com` on the preflight response.
- The app loads in the browser; **Network → Disable cache** then a hard reload should still work.

---

## 11. Common pitfalls

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `SSL_ERROR_BAD_CERT_DOMAIN` in browser | Cloudflare DNS record set to **DNS-only** instead of **Proxied** | Switch the record to proxied (orange cloud). |
| `526 Invalid SSL certificate` from Cloudflare | SSL/TLS mode is **Full (strict)** | Set to **Full** for this host (GCS doesn’t present a cert for the custom domain). |
| HTTP 404 on `/` | Bucket name does not match the FQDN, or `MainPageSuffix` not set | Recreate bucket with name `app.deepdownidea.com`, or run `gcloud storage buckets update --web-main-page-suffix=index.html`. |
| Users see old build after deploy | Long-cached `index.html` at edge or browser | Confirm `Cache-Control: no-cache, must-revalidate` on `index.html`; purge Cloudflare entry-point URLs after each deploy. |
| `XMLHttpRequest … blocked by CORS policy` | New web origin not in backend `CORS_ORIGINS` | Add `https://app.deepdownidea.com` and restart the API. |
| Service worker keeps serving stale code | Old `flutter_service_worker.js` cached | Ensure short cache on `flutter_service_worker.js`; users may need one extra reload (worker activates on next visit). |
| 404 status on deep links | Path URL strategy without SPA fallback | See [§ 8](#8-spa-fallback-path-url-strategy). |

---

## 12. Alternatives (when GCS + Cloudflare isn’t a fit)

- **Cloudflare Pages / R2** — simpler deploy via `wrangler`; no GCS account needed. Good if you’re happy to keep static hosting inside Cloudflare.
- **Firebase Hosting** — opinionated, built-in SPA rewrites, atomic deploys; uses Google’s edge instead of Cloudflare.
- **GCS + Cloud Load Balancer + Google-managed cert** — needed if your org enforces public-access prevention or you want **Full (strict)** end-to-end. More moving parts and cost.

For an admin UI of this size, **GCS + Cloudflare proxy** is the cheapest and fastest to set up.
