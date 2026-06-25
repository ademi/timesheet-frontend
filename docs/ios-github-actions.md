# iOS builds with GitHub Actions (no Mac required)

Build and distribute the Flutter app to iPhones using **GitHub-hosted macOS runners**. You do not need a local Mac; you **do** need an **Apple Developer Program** membership ($99/year) to produce an installable IPA for testers.

Workflow file: [`.github/workflows/ios-build.yml`](../.github/workflows/ios-build.yml)

---

## What the workflow does

| Mode | When | Result |
|------|------|--------|
| **Unsigned** | Signing secrets not configured | Verifies the project compiles on iOS; **cannot** be installed on a phone |
| **Signed IPA** | P12 + provisioning profile secrets set | Downloadable `.ipa` artifact from the Actions run |
| **TestFlight** | Signed build + App Store Connect API key + `upload_testflight: true` | Testers install via the TestFlight app |

---

## Prerequisites

1. **Apple Developer Program** — [developer.apple.com/programs](https://developer.apple.com/programs/)
2. **GitHub repo** for `frontend` pushed to GitHub
3. **Bundle ID** — register one in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) (replace `com.deepdownidea.timesheet`)
4. **Distribution certificate** (.p12) and **provisioning profile**:
   - **TestFlight:** *Apple Distribution* cert + *App Store* profile
   - **Direct to 2 devices:** *Apple Distribution* cert + *Ad Hoc* profile (register each device UDID first)

---

## One-time: create signing assets

### 1. Create a distribution certificate (Keychain Access on any Mac, or ask someone with a Mac)

1. Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority
2. In [Apple Developer → Certificates](https://developer.apple.com/account/resources/certificates/list), create **Apple Distribution**
3. Download, install in Keychain, export as **`.p12`** with a password

### 2. Create a provisioning profile

- **TestFlight:** Profiles → **App Store** → select your App ID → download `.mobileprovision`
- **Ad hoc (2 testers):** Profiles → **Ad Hoc** → select App ID → add both device UDIDs → download

Testers find UDID: connect iPhone to a Mac → Finder → device info, or use a UDID lookup site.

### 3. Base64-encode for GitHub Secrets

```bash
base64 -i Certificates.p12 | pbcopy          # macOS
base64 -w0 Certificates.p12                  # Linux
base64 -i profile.mobileprovision | pbcopy
```

---

## GitHub configuration

### Repository secrets

| Secret | Description |
|--------|-------------|
| `IOS_P12_BASE64` | Base64-encoded `.p12` distribution certificate |
| `IOS_P12_PASSWORD` | Password used when exporting the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded `.mobileprovision` |
| `IOS_KEYCHAIN_PASSWORD` | Any strong random string (CI-only temp keychain) |
| `APPLE_TEAM_ID` | 10-character Team ID (Membership details in Apple Developer) |

**Optional — TestFlight upload:**

| Secret | Description |
|--------|-------------|
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect → Users and Access → Keys |
| `APP_STORE_CONNECT_KEY_ID` | API key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contents of the `.p8` key file |

### Repository variables

Settings → Secrets and variables → Actions → **Variables**:

| Variable | Example |
|----------|---------|
| `IOS_BUNDLE_ID` | `com.yourcompany.yemengate` |
| `IOS_PROVISIONING_PROFILE_NAME` | Exact name shown in Apple Developer for the profile |

---

## Run a build

1. Push the frontend repo to GitHub (workflow lives under `frontend/.github/`).
2. Actions → **Build iOS** → **Run workflow**
3. Set **API base URL** (default: `https://timesheetbackend.deepdownidea.com`)
4. Choose **distribution_method**:
   - `app-store` → TestFlight / App Store Connect
   - `ad-hoc` → install only on UDIDs in the profile
5. Optionally enable **Upload TestFlight**

Or tag a release: `git tag v1.0.0 && git push origin v1.0.0`

---

## Give builds to 2 testers

### Option A — TestFlight (recommended)

1. Create the app in [App Store Connect](https://appstoreconnect.apple.com) with the same bundle ID.
2. Run workflow with `upload_testflight: true`.
3. In App Store Connect → TestFlight → add testers by email (internal or external).
4. Testers install Apple’s **TestFlight** app and accept the invite.

### Option B — Ad hoc IPA

1. Register both iPhones’ UDIDs in the Ad Hoc profile.
2. Re-download profile, update `IOS_PROVISIONING_PROFILE_BASE64`, rebuild with `ad-hoc`.
3. Download the `.ipa` artifact from Actions.
4. Install with **Apple Configurator**, **Xcode Devices**, or a link service (e.g. Diawi) — testers may need to trust the developer certificate in Settings → General → VPN & Device Management.

### Option C — No Apple account (web only)

Use [web-deploy-gcs-cloudflare.md](./web-deploy-gcs-cloudflare.md) instead; no GitHub iOS workflow needed.

---

## Build command (local reference)

Same flags the workflow uses:

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://timesheetbackend.deepdownidea.com \
  --export-options-plist=ios/ExportOptions.plist
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Workflow only produces unsigned build | Add all signing secrets and variables from the tables above |
| `No signing certificate "iOS Distribution" found` | Use an **Apple Distribution** cert in the `.p12`, not Apple Development |
| Provisioning profile doesn't match | `IOS_BUNDLE_ID` must match the profile’s App ID exactly |
| TestFlight upload fails | App record must exist in App Store Connect; first upload may need manual compliance in ASC |
| GPS not working on device | Add `NSLocationWhenInUseUsageDescription` to `ios/Runner/Info.plist` |
| Push not working on iOS | Add `GoogleService-Info.plist` from Firebase console |

---

## Cost notes

- **GitHub Actions:** macOS minutes consume **10×** Linux minutes on free/private plans; a typical Flutter iOS build is ~15–30 min.
- **Alternatives:** [Codemagic](https://codemagic.io), [Bitrise](https://bitrise.io), and [GitLab macOS runners](https://docs.gitlab.com/ee/ci/runners/) offer similar Flutter+iOS CI with their own pricing.
