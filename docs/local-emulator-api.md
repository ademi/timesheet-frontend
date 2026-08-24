# Local API — Android emulator

**Release builds deny cleartext HTTP** (manifest + `assertReleaseHttps`); use a **debug** or **profile** run for local HTTP below.

Run the backend on the host (`uvicorn` on port 8000), then wire the emulator:

```bash
adb reverse tcp:8000 tcp:8000
cd frontend
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

**Why not `10.0.2.2` alone?** Dogfood (2026-07-31) hit flaky connectivity; `adb reverse` + `127.0.0.1` was reliable.

## VS Code

Root workspace `.vscode/launch.json` — **Android: frontend** — should include:

```json
"toolArgs": [
  "--dart-define=API_BASE_URL=http://127.0.0.1:8000"
]
```

No secrets in launch configs.

## Related API paths

- Access history: `GET /v1/compliance/access-history?credential_id=…` (not `/v1/access-history`).
- Documents list: `GET /v1/documents?owner_type=…&owner_id=…` (both required).
