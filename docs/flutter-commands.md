# Flutter commands — Timesheet frontend

Reference for day-to-day Flutter/Dart work on **yemen_gate_attendance_app**. All commands assume the app directory unless noted otherwise.

```bash
cd /home/ademi/projects/timesheet/frontend
```

---

## Prerequisites


| Tool        | Purpose                                                                   |
| ----------- | ------------------------------------------------------------------------- |
| Flutter SDK | `flutter --version` (project SDK: **^3.7.2** in `pubspec.yaml`)           |
| Android SDK | Emulator / APK builds (`flutter doctor`)                                  |
| Chrome      | Web debug and `flutter run -d chrome`                                     |
| Backend API | Usually `http://localhost:8000` (see [Backend pairing](#backend-pairing)) |


Check setup:

```bash
flutter doctor -v
```

---

## Dependencies

Resolve packages after clone or `pubspec.yaml` changes:

```bash
flutter pub get
```

See outdated constraints:

```bash
flutter pub outdated
```

---

## API base URL (environments)

The API origin is set at **compile time** via `--dart-define=API_BASE_URL=...` (see `lib/core/constants/app_constants.dart`).


| Environment                          | Typical `API_BASE_URL`                                        | Device                                    |
| ------------------------------------ | ------------------------------------------------------------- | ----------------------------------------- |
| **Production (default)**             | *(omit define)* → `https://timesheetbackend.deepdownidea.com` | Release builds                            |
| **Local backend (web/desktop)**      | `http://localhost:8000`                                       | Chrome, Linux                             |
| **Local backend (Android emulator)** | `http://10.0.2.2:8000`                                        | `emulator-`* (host machine from emulator) |
| **Local backend (physical Android)** | `http://<your-LAN-IP>:8000`                                   | USB device on same Wi‑Fi                  |


`localhost` on the **Android emulator** points at the emulator itself, not your PC — use `10.0.2.2` instead.

Tenant/branch IDs are fixed in `AppConstants` for dev (`tenantId`, `branchId`).

---

## Devices and emulators

List connected devices and emulators:

```bash
flutter devices
```

List AVDs and start one:

```bash
flutter emulators
flutter emulators --launch flutter_api36
```

Wait until ADB shows the device (often `emulator-5554`):

```bash
adb devices
```

---

## Run (debug)

### Chrome — local API (common for admin/payroll UI)

Matches VS Code **“Chrome: frontend (local APIs)”**:

```bash
flutter run -d chrome \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:8000
```

### Chrome — default / remote API

Uses production default URL (no define):

```bash
flutter run -d chrome --web-port=3000
```

### Android emulator — local API

Used in this project when debugging on `emulator-5554`:

```bash
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Start emulator first if needed (`flutter emulators --launch flutter_api36`).

### Android — pick any connected device

```bash
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### Linux desktop (if enabled for the project)

```bash
flutter run -d linux \
  --dart-define=API_BASE_URL=http://localhost:8000
```

### While `flutter run` is active


| Key | Action      |
| --- | ----------- |
| `r` | Hot reload  |
| `R` | Hot restart |
| `q` | Quit        |


---

## VS Code / Cursor launch configs

From `.vscode/launch.json` (workspace root):


| Configuration                      | Device          | API                                                                                                                                       |
| ---------------------------------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| **Android: frontend (local APIs)** | `emulator-5554` | Add `--dart-define=API_BASE_URL=...` in `toolArgs` if not set (launch config currently has no define; use CLI above or extend `toolArgs`) |
| **Chrome: frontend (local APIs)**  | `chrome`        | `http://localhost:8000`, port `3000`                                                                                                      |
| **Chrome: frontend (debug login)** | `chrome`        | Default remote URL, port `3000`                                                                                                           |


Backend should be running separately (**Timesheet API** launch → uvicorn on port `8000`).

---

## Testing

Run the full test suite:

```bash
flutter test
```

Run specific tests (examples used in this project):

```bash
# Navigation / GetX regression
flutter test test/app/routes/app_navigation_test.dart
flutter test test/app/navigation/employee_rates_navigation_test.dart

# Controllers
flutter test test/app/controllers/create_payment_controller_test.dart
flutter test test/app/controllers/employee_rate_form_controller_test.dart
flutter test test/app/controllers/employee_detail_controller_test.dart

# Utilities
flutter test test/app/utils/attendance_report_matrix_test.dart

# Single file
flutter test test/app/controllers/employee_rate_form_controller_test.dart -v
```

Widget smoke test:

```bash
flutter test test/widget_test.dart
```

---

## Analyze and format

Static analysis (CI-friendly):

```bash
flutter analyze
```

Analyze one file or folder:

```bash
flutter analyze lib/app/controllers/employee_rates_controller.dart
```

Format Dart sources:

```bash
dart format lib test
```

---

## Build (release / artifacts)

Always pass the correct `API_BASE_URL` for the target environment. Production example:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://timesheetbackend.deepdownidea.com
```

### Web

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://timesheetbackend.deepdownidea.com
```

Output: `build/web/`

Local/staging web against dev API:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=http://localhost:8000
```

### Android APK (side-load / QA)

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://timesheetbackend.deepdownidea.com
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

Debug APK (faster, no minify):

```bash
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### Android App Bundle (Play Store)

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://timesheetbackend.deepdownidea.com
```

### iOS (on macOS with Xcode toolchain)

```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://timesheetbackend.deepdownidea.com
```

### Windows / Linux desktop

```bash
flutter build windows --release \
  --dart-define=API_BASE_URL=https://timesheetbackend.deepdownidea.com

flutter build linux --release \
  --dart-define=API_BASE_URL=http://localhost:8000
```

---

## Clean rebuild

After plugin or native changes, or odd build cache issues:

```bash
flutter clean
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

---

## Backend pairing

Typical local stack:

1. Start Postgres (e.g. Docker `postgres-server`).
2. Apply migrations: `backend/timesheet-db/scripts/apply_migrations.sh`
3. Start API from `backend/timesheet-backend` (VS Code **Timesheet API** or):
  ```bash
   cd backend/timesheet-backend
   DOTENV_PATH=../local.env uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
  ```
4. Run Flutter against `http://localhost:8000` (web) or `http://10.0.2.2:8000` (Android emulator).

---

## Backend tests (related)

Python API tests are separate from Flutter; run from `backend/timesheet-backend`:

```bash
DOTENV_PATH=../.env uv run pytest tests -v
```

VS Code: **Pytest: Timesheet API** (uses `backend/.env` and `timesheet_test` when configured).

---

## Quick reference cheat sheet

```bash
# Setup
cd frontend && flutter pub get && flutter doctor

# Dev — web + local API
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:8000

# Dev — Android emulator + local API
flutter emulators --launch flutter_api36
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Quality
flutter analyze
flutter test

# Release web
flutter build web --release --dart-define=API_BASE_URL=https://timesheetbackend.deepdownidea.com
```

---

## Notes from this project

- **GetX routing:** Prefer helpers in `lib/app/routes/app_navigation.dart` (e.g. `pushNamedBool`) instead of `Get.toNamed<bool>` on web — generic route types can throw on Flutter Web.
- **Web port:** Admin UI is often opened at `http://localhost:3000` when using `--web-port=3000`.
- **Package name:** `yemen_gate_attendance_app` (import path in tests).

## to debug on device:
- get the IP
hostname -I 2>/dev/null | awk '{print $1}'; ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}'
- start debugging
flutter run -d R5CRB12PY2D \
  --dart-define=AUTH_BASE_URL=http://192.168.197.8:9090 \
  --dart-define=FARMING_SERVICE_BASE_URL=http://192.168.197.8:8100