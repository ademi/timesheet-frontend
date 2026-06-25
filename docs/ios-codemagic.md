# iOS builds with Codemagic

Build and distribute the Flutter app to iPhones using [Codemagic](https://codemagic.io) macOS build machines. You do not need a local Mac; you **do** need an **Apple Developer Program** membership ($99/year) to produce an installable IPA for testers.

This guide covers:

1. **Manual builds** — start a build from the Codemagic UI on any branch.
2. **CI/CD** — automatic builds when you push to the **`ios`** branch.

For GitHub Actions instead of Codemagic, see [ios-github-actions.md](./ios-github-actions.md).

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

1. Open the application → **Repository settings** (or team **Integrations**).
2. Confirm the webhook is installed for your Git provider.
3. If prompted during setup, grant Codemagic access to the repo.

Without a webhook, you can still run **manual** builds from the UI, but pushes will not trigger builds automatically.

### 3. Upload iOS code signing identities

Team settings → **codemagic.yaml settings** → **Code signing identities**:

| Asset | Tab | Notes |
|-------|-----|-------|
| Distribution certificate (`.p12`) | iOS certificates | **Apple Distribution**, not Development |
| Provisioning profile | iOS provisioning profiles | App Store profile for TestFlight; Ad Hoc for direct device installs |

Alternatively, connect an **App Store Connect API key** and use **Fetch certificate** / **Fetch profiles** in the Codemagic UI.

### 4. App Store Connect integration (optional, for TestFlight)

1. Create an API key in [App Store Connect → Users and Access → Integrations](https://appstoreconnect.apple.com/access/integrations/api).
2. Codemagic → Team settings → **Team integrations** → **App Store Connect** → add the key (name it e.g. `timesheet`).
3. Reference that name in `codemagic.yaml` under `integrations.app_store_connect`.

### 5. Environment variable group (recommended)

Team settings → **Environment variables** → create a group (e.g. `timesheet_ios`) with:

| Variable | Example | Purpose |
|----------|---------|---------|
| `API_BASE_URL` | `https://timesheetbackend.deepdownidea.com` | Passed to `--dart-define=API_BASE_URL=...` |
| `IOS_BUNDLE_ID` | `com.yourcompany.yemengate` | Must match Apple Developer App ID and provisioning profile |

Mark secrets (API keys, passwords) as **Secure**. Reference the group in `codemagic.yaml` via `environment.groups`.

---

## CI/CD: push to the `ios` branch

### Add `codemagic.yaml`

Commit a `codemagic.yaml` file at the **repository root** (`frontend/codemagic.yaml`). Codemagic reads this file instead of the Workflow Editor when it is present.

Example workflow tailored to this project — builds automatically on every push to branch **`ios`**:

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
      app_store_connect: timesheet   # ← your App Store Connect integration name

    environment:
      groups:
        - timesheet_ios               # ← group with API_BASE_URL, IOS_BUNDLE_ID
      ios_signing:
        distribution_type: app_store  # use ad_hoc for registered-device IPA
        bundle_identifier: $IOS_BUNDLE_ID
      flutter: stable
      xcode: latest

    scripts:
      - name: Set up code signing
        script: xcode-project use-profiles

      - name: Install dependencies
        script: flutter pub get

      - name: Install CocoaPods
        script: find . -name "Podfile" -execdir pod install \;

      - name: Build signed IPA
        script: |
          flutter build ipa --release \
            --dart-define=API_BASE_URL="${API_BASE_URL:-https://timesheetbackend.deepdownidea.com}"

    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log

    publishing:
      email:
        recipients:
          - your-team@example.com
        notify:
          success: true
          failure: true
      app_store_connect:
        auth: integration
        submit_to_testflight: false   # set true to upload after each ios-branch push
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

1. Open the application in Codemagic.
2. Click **Start new build**.
3. Choose the **workflow** (e.g. **iOS (ios branch)** or a manual-only workflow — see below).
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
      - name: Set up code signing
        script: xcode-project use-profiles
      - name: Install dependencies
        script: flutter pub get
      - name: Build signed IPA
        script: |
          flutter build ipa --release \
            --dart-define=API_BASE_URL="${API_BASE_URL:-https://timesheetbackend.deepdownidea.com}"
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
| Wrong API URL in the app | Set `API_BASE_URL` in the Codemagic environment group or override when starting a manual build |
| TestFlight upload fails | App record must exist in App Store Connect; check App Store Connect integration name matches `integrations.app_store_connect` |
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
