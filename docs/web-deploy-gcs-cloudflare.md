# Deploying Flutter web to GCS + Cloudflare (archived)

**Status: superseded.** Production web hosting is now a Cloudflare Worker with Static Assets.

→ Use **[web-deploy-cloudflare-workers.md](./web-deploy-cloudflare-workers.md)**  
→ Config: `wrangler.toml` · CI: `.github/workflows/deploy-web.yml` · Script: `scripts/deploy_web_workers.sh`

The previous GCS bucket + Cloudflare proxy runbook is kept only for historical reference. Do not use it for new deploys of `app.rostiq.co`.
