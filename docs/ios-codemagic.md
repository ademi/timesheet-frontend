# iOS builds with Codemagic

Build and distribute the Flutter app to iPhones using [Codemagic](https://codemagic.io) macOS build machines. You do not need a local Mac; you **do** need an **Apple Developer Program** membership ($99/year) to produce an installable IPA for testers.

This guide covers:

1. **Manual builds** — start a build from the Codemagic UI on any branch.
2. **CI/CD** — automatic builds when you push to the **`ios`** branch.

It assumes a **single Codemagic application** for this `frontend` repo (personal account or one app in a team). Per-app configuration lives under **App settings**; account-wide signing and API keys live under **User settings** (personal account) because this project builds with [`codemagic.yaml`](../codemagic.yaml).

For GitHub Actions instead of Codemagic, see [ios-github-actions.md](./ios-github-actions.md).

---

## Where to click in Codemagic

| What | Where (individual application) |
|------|--------------------------------|
| Environment variables (`timesheet_ios` group) | **Applications** → your app → **App settings** → **Environment variables** |
| Repository webhook | **Applications** → your app → **App settings** → **Repository settings** |
| Start a manual build | **Applications** → your app → **Start new build** |
| App Store Connect API key | **User settings** → **Integrations** → **Developer Portal** |
| iOS certificates & provisioning profiles (for `codemagic.yaml`) | **User settings** → **codemagic.yaml** → **Code signing identities** |

Direct URL patterns:

- App: `https://codemagic.io/app/<app-id>/settings`
- User settings: `https://codemagic.io/user-settings`

On a **shared team account**, the same account-wide items appear under **Team settings** instead of **User settings**.

> **Note:** Because `codemagic.yaml` is committed, Codemagic **ignores** the Workflow Editor and **App settings → Distribution** for build steps. Signing is wired through `environment.ios_signing` in the YAML and certificates/profiles stored under **User settings → Code signing identities**.

---

## What you get

| Mode | When | Result |
|------|------|--------|
| **Unsigned** | Signing not configured in Codemagic | Compile check only; **cannot** be installed on a phone |
| **Signed IPA** | iOS code signing identities set up | Downloadable `.ipa` from the build page |
| **TestFlight** | Signed build + App Store Connect integration + `submit_to_testflight: true` | Testers install via the TestFlight app |

The default production API URL baked into release builds is `https://timesheetbackend.deepdownidea.com` (same as the GitHub Actions workflow).

---

## Prerequisites

1. **Apple Developer Program** — [developer.apple.com/programs](https://developer.apple.com/programs/)
2. **Codemagic account** — [codemagic.io/signup](https://codemagic.io/signup)
3. **Git repository** — this `frontend` repo connected to Codemagic
4. **Bundle ID** — register one in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) (replace `com.deepdownidea.timesheet` in `ios/Runner.xcodeproj/project.pbxproj`)
5. **Distribution certificate** and **provisioning profile** (App Store for TestFlight, or Ad Hoc for registered devices)

Signing asset creation steps are the same as in [ios-github-actions.md](./ios-github-actions.md#one-time-create-signing-assets).

---

## One-time Codemagic setup

### 1. Add the application

1. Codemagic → **Applications** → **Add application**.
2. Select your team (if prompted).
3. Connect the Git host (GitHub, GitLab, Bitbucket, etc.) and choose this **`frontend`** repository.
4. Select project type **Flutter** → **Finish: Add application**.

### 2. Enable automatic builds (webhook)

For CI/CD on push to `ios`, Codemagic must receive repository webhooks:

1. **Applications** → select this app → **App settings** → **Repository settings**.
2. Confirm the webhook is installed for your Git provider.
3. If prompted, grant Codemagic access to the repo.

Without a webhook, you can still run **manual** builds from the app page, but pushes will not trigger builds automatically.

### 3. Upload iOS code signing identities

Because builds use `codemagic.yaml`, upload signing files under your **personal account** (not per-app Distribution UI):

**User settings** → **codemagic.yaml** → **Code signing identities**:

| Asset | Tab | Notes |
|-------|-----|-------|
| Distribution certificate (`.p12`) | iOS certificates | **Apple Distribution**, not Development |
| Provisioning profile | iOS provisioning profiles | App Store profile for TestFlight; Ad Hoc for direct device installs |

Alternatively, add an App Store Connect API key (step 4), then use **Generate certificate** / **Fetch profiles** on the same page.

The workflow selects files that match `distribution_type: app_store` and `$IOS_BUNDLE_ID` from the `timesheet_ios` environment group (see step 5).

### 4. App Store Connect integration (for TestFlight)

1. Create an API key in [App Store Connect → Users and Access → Integrations](https://appstoreconnect.apple.com/access/integrations/api).
2. **User settings** → **Integrations** → **Developer Portal** → **Connect** (or **Manage keys**).
3. **API key name:** `codemagic` (must match `integrations.app_store_connect` in [`codemagic.yaml`](../codemagic.yaml)).
4. Enter **Issuer ID**, **Key ID**, upload the `.p8` file → **Save**.

### 5. Environment variable group (app settings)

Variables for this app live under **App settings**, not team-wide settings. The committed [`codemagic.yaml`](../codemagic.yaml) imports group **`timesheet_ios`**.

#### How to open App settings

1. Sign in at [codemagic.io](https://codemagic.io).
2. **Applications** → select the **frontend** / Timesheet app.
3. Click the **gear icon** (**App settings**).

#### How to add the `timesheet_ios` group

1. Open the **Environment variables** tab.
2. Click **Add variable**.
3. Enter **Variable name** and **Variable value**.
4. In **Variable group**, type `timesheet_ios` and create the group (or select it when adding the second variable).
5. Toggle **Secret** for sensitive values so they are encrypted and hidden in logs.
6. Click **Add**.

Repeat for each variable:

| Variable | Example | Purpose |
|----------|---------|---------|
| `API_BASE_URL` | `https://timesheetbackend.deepdownidea.com` | Passed to `--dart-define=API_BASE_URL=...` |
| `IOS_BUNDLE_ID` | `com.deepdownidea.timesheet` | Must match Apple Developer App ID and provisioning profile |

The group is referenced in `codemagic.yaml`:

```yaml
environment:
  groups:
    - timesheet_ios
```

---

## CI/CD: push to the `ios` branch

### Add `codemagic.yaml`

Commit [`codemagic.yaml`](../codemagic.yaml) at the **repository root** (`frontend/codemagic.yaml`). Codemagic reads this file instead of the Workflow Editor when it is present.

The committed workflow builds automatically on every push to branch **`ios`**:

```yaml
workflows:
  ios-branch:
    name: iOS (ios branch)
    instance_type: mac_mini_m2
    max_build_duration: 60

    triggering:
      events:
        - push
      branch_patterns:
        - pattern: '^ios$'
          include: true
      cancel_previous_builds: true

    integrations:
      app_store_connect: codemagic   # User settings → Integrations → Developer Portal

    environment:
      groups:
        - timesheet_ios                  # App settings → Environment variables
      ios_signing:
        distribution_type: app_store
        bundle_identifier: $IOS_BUNDLE_ID
      flutter: stable
      xcode: latest

    scripts:
      - name: Install dependencies
        script: flutter pub get
      - name: Install CocoaPods
        script: find . -name "Podfile" -execdir pod install \;
      - name: Set up code signing
        script: xcode-project use-profiles
      - name: Build signed IPA
        script: |
          flutter build ipa --release \
            --dart-define=API_BASE_URL="${API_BASE_URL:-https://timesheetbackend.deepdownidea.com}" \
            --export-options-plist=/Users/builder/export_options.plist

    artifacts:
      - build/ios/ipa/*.ipa

    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
```

**Branch trigger behaviour**

- Only pushes to a branch literally named `ios` start a build (`pattern: '^ios$'`).
- To match branches such as `feature/ios-payments`, change the pattern to `'^ios$|^feature/ios-.*$'` or use `'*ios*'` (broader).
- `cancel_previous_builds: true` aborts an in-flight build when a newer push lands on `ios` (similar to GitHub Actions concurrency).

### Typical CI/CD workflow

```bash
# From your machine — work on ios-specific changes
git checkout ios || git checkout -b ios
# ... edit, commit ...
git push origin ios
```

Codemagic starts **iOS (ios branch)** automatically. Monitor progress under **Builds** in the Codemagic UI or via email/Slack if configured.

### Merge from other branches

To ship iOS changes that were developed on `main` or a feature branch:

```bash
git checkout ios
git merge main          # or: git cherry-pick <commit>
git push origin ios     # triggers Codemagic
```

Keep `ios` as an integration/release branch, or reset it to track `main` before each release — whichever fits your process.

---

## Manual builds (any branch)

Use manual builds for one-off releases, testing signing, or building from `main` without changing branch triggers.

### Option A — Start from Codemagic UI

1. **Applications** → select this app.
2. Click **Start new build**.
3. Choose workflow **iOS (ios branch)** (or **iOS (manual)** if you add that workflow).
4. Select **branch** and **commit** (any branch, not only `ios`).
5. Click **Start new build**.

Manual starts work even when `triggering` is configured; you are not limited to the `ios` branch.

### Option B — Separate manual-only workflow

Add a second workflow in `codemagic.yaml` with **no** `triggering` section so it never runs on push — only from the UI:

```yaml
  ios-manual:
    name: iOS (manual)
    instance_type: mac_mini_m2
    max_build_duration: 60
  # no triggering: block — manual only
    environment:
      groups:
        - timesheet_ios
      ios_signing:
        distribution_type: app_store
        bundle_identifier: $IOS_BUNDLE_ID
      flutter: stable
      xcode: latest
    scripts:
      - name: Install dependencies
        script: flutter pub get
      - name: Set up code signing
        script: xcode-project use-profiles
      - name: Build signed IPA
        script: |
          flutter build ipa --release \
            --dart-define=API_BASE_URL="${API_BASE_URL:-https://timesheetbackend.deepdownidea.com}" \
            --export-options-plist=/Users/builder/export_options.plist
    artifacts:
      - build/ios/ipa/*.ipa
```

### Option C — Codemagic REST API

For automation outside Git (e.g. internal tooling), trigger a build via the [Codemagic REST API](https://docs.codemagic.io/rest-api/overview/):

```bash
curl -H "Content-Type: application/json" \
  -H "x-auth-token: $CODEMAGIC_API_TOKEN" \
  -d '{
    "appId": "YOUR_APP_ID",
    "workflowId": "ios-branch",
    "branch": "ios"
  }' \
  https://api.codemagic.io/builds
```

Create an API token under Codemagic → **User settings** → **API tokens**.

---

## Distribute to testers

### TestFlight (recommended)

1. Create the app in [App Store Connect](https://appstoreconnect.apple.com) with the same bundle ID as `IOS_BUNDLE_ID`.
2. Set `submit_to_testflight: true` under `publishing.app_store_connect` in `codemagic.yaml`, or upload the `.ipa` manually from the build artifacts.
3. App Store Connect → **TestFlight** → add testers by email.

### Ad hoc IPA

1. Set `distribution_type: ad_hoc` under `environment.ios_signing`.
2. Register device UDIDs in the Ad Hoc provisioning profile and re-upload the profile to Codemagic.
3. Download the `.ipa` from the build page and distribute via Apple Configurator, Xcode Devices, or a link service.

---

## Build command (local reference)

Same flags Codemagic uses:

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://timesheetbackend.deepdownidea.com
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Push to `ios` does not start a build | Confirm `codemagic.yaml` is on the `ios` branch; webhook is installed; `triggering.branch_patterns` matches the branch name |
| Build only in Workflow Editor, ignores YAML | `codemagic.yaml` must be at repo root; click **Check for configuration file** after pushing |
| Code signing failed | Upload **Apple Distribution** `.p12` and matching profile; `IOS_BUNDLE_ID` must match the profile App ID |
| `use-profiles` OK but `exportArchive requires a provisioning profile` | Run `xcode-project use-profiles` **after** `pod install`; pass `--export-options-plist=/Users/builder/export_options.plist` to `flutter build ipa` |
| Wrong API URL in the app | Set `API_BASE_URL` in **App settings → Environment variables** (`timesheet_ios` group) |
| TestFlight upload fails | App record must exist in App Store Connect; integration name must be `codemagic` in YAML and **User settings → Integrations** |
| GPS not working on device | Add `NSLocationWhenInUseUsageDescription` to `ios/Runner/Info.plist` |
| Push not working on iOS | Add `GoogleService-Info.plist` from Firebase console |

---

## Codemagic vs GitHub Actions

| | Codemagic | GitHub Actions ([ios-github-actions.md](./ios-github-actions.md)) |
|--|-----------|---------------------------------------------------------------------|
| **Trigger** | Push to `ios` (this guide) or manual | Tags `v*.*.*` or manual **Run workflow** |
| **macOS minutes** | Codemagic plan (often simpler for Flutter+iOS) | GitHub macOS minutes cost **10×** Linux minutes |
| **Signing** | Upload once to Codemagic; optional auto-fetch from Apple | Base64 secrets in GitHub (`IOS_P12_BASE64`, etc.) |
| **Config** | `codemagic.yaml` at repo root | `.github/workflows/ios-build.yml` |

You can use both: GitHub Actions for tagged releases and Codemagic for continuous builds on the `ios` branch.

---

## Cost notes

- Codemagic offers a free tier with a monthly build-minute allowance; see [codemagic.io/pricing](https://codemagic.io/pricing).
- macOS builds typically take **15–30 minutes** for a Flutter iOS release build.
- `cancel_previous_builds: true` avoids paying for stacked builds when `ios` receives rapid pushes.
