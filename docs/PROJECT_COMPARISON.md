# Project Comparison: Original vs Forked Version

**Original:** `C:\Users\DELL3561\StudioProjects\rostiq`  
**Fork (current workspace):** `C:\Users\DELL3561\Desktop\new projects\timesheet-new\timesheet-frontend`

---

## 1. Executive Summary

The fork is a **major expansion**, not a small patch set. Your original app was a focused attendance + basic payments tool (~66 Dart files in `lib/`). The fork roughly **doubles the codebase** (~139 files) and adds several **brand-new product areas**, especially **payroll**, **employee management**, and **auth/security hardening**.

High-level change mix:

| Category | Scale |
|---|---|
| **Brand-new features** | Large — full payroll module, employee detail hub, PIN-based clock-in, push notifications, first-login flow |
| **UI/UX improvements** | Significant — admin panel redesigned from tabs to hub cards; many new screens |
| **Backend integration** | Extensive — new API endpoints, dynamic tenant/branch handling, production API URL |
| **Security & auth** | Major — secure token storage, proactive refresh, PIN auth, removed hardcoded credentials |
| **Bug fixes / polish** | Moderate — live clock duration, role support, currency defaults, edit-mode UX |

**Bottom line:** The fork is mostly **new features + architectural/security upgrades**, with meaningful UI restructuring. It is production-oriented (hosted backend, Firebase, secure storage), while your original was more of a local-dev prototype.

---

## 2. New Features Added

### Feature 1: Full Payroll Module

- **Description:** End-to-end payroll management — periods (create/calculate/close), employee rates, balances, period results, summary reports, and CSV export.
- **Key Files Modified/Added:**
  - `lib/app/views/payroll_main_view.dart`
  - `lib/app/views/payroll_periods_view.dart`, `payroll_period_detail_view.dart`, `payroll_period_results_view.dart`, `payroll_result_detail_view.dart`
  - `lib/app/views/payroll_summary_report_view.dart`, `employee_balance_view.dart`, `employee_rates_view.dart`, `employee_rate_form_view.dart`
  - `lib/app/controllers/payroll_*_controller.dart` (6 controllers)
  - `lib/app/data/repositories/payroll_repository.dart`
  - `lib/app/data/datasources/remote/payroll_remote_datasource.dart`
  - `lib/app/data/models/payroll/*` (8 model files)
- **Impact:** Transforms the app from attendance/payments only into a full HR/payroll admin tool.

---

### Feature 2: Employee Detail & Management Hub

- **Description:** Dedicated employee list and profile screen with editable details, role assignment, default currency, payroll snapshot, rates, attendance history, balance link, and **PIN reset**.
- **Key Files Modified/Added:**
  - `lib/app/views/employee_management_view.dart`
  - `lib/app/views/employee_detail_view.dart`
  - `lib/app/views/employee_created_view.dart`
  - `lib/app/controllers/employee_detail_controller.dart`, `employee_management_controller.dart`
  - `lib/app/data/repositories/employee_repository.dart`
  - `lib/app/data/datasources/remote/employee_remote_datasource.dart`
  - `lib/app/data/models/attendance/employee_update_request.dart`, `employee_role_option.dart`, `time_entry_out.dart`
- **Impact:** Admins can manage employees in one place instead of a simple tab inside the admin panel.

---

### Feature 3: PIN-Based Attendance (replacing password confirmation)

- **Description:** Clock-in/out now uses a **4-digit PIN** (`verify_pin`, `set_pin`) instead of re-entering the account password. First-time users are prompted to set a PIN.
- **Key Files Modified/Added:**
  - `lib/app/views/widgets/attendance_pin_dialog.dart`, `pin_input_field.dart`, `set_pin_dialog.dart`
  - `lib/app/controllers/attendance_controller.dart` (rewritten)
  - `lib/app/data/models/auth/verify_pin_*`, `set_pin_request_model.dart`
  - **Removed from original:** `attendance_password_dialog.dart`, `change_password_dialog.dart`
- **Impact:** Better UX for staff on shared tablets; aligns with backend PIN API. Removes the original hardcoded default password (`123456`) flow.

---

### Feature 4: First-Login / Must-Change-Password Flow

- **Description:** When the backend returns `must_change_password`, users are redirected to a first-login screen to set a new password before continuing.
- **Key Files Modified/Added:**
  - `lib/app/views/first_login_view.dart`
  - `lib/app/controllers/first_login_controller.dart`
  - `lib/core/network/must_change_password.dart`
  - `lib/core/validation/password_validation.dart`
  - `lib/app/data/models/auth/first_login_request_model.dart`
- **Impact:** Supports secure onboarding for new admin accounts.

---

### Feature 5: Secure Token Storage & Session Management

- **Description:** Tokens moved from `GetStorage` to **`flutter_secure_storage`** (Keychain/Keystore). JWT expiry is checked for proactive refresh on app resume.
- **Key Files Modified/Added:**
  - `lib/core/services/token_storage.dart`
  - `lib/main.dart` (lifecycle observer + proactive refresh)
  - `lib/core/network/auth_interceptor.dart` (updated to use `TokenStorage`)
- **Impact:** Much stronger session security; fewer unexpected logouts; background-resume handling.

---

### Feature 6: Firebase Push Notifications

- **Description:** Registers device FCM tokens with the backend after login (`POST /v1/notifications/devices`).
- **Key Files Modified/Added:**
  - `lib/app/services/push_notification_service.dart`
  - `lib/app/controllers/auth_controller.dart` (registers token post-login)
- **Impact:** Enables server-pushed alerts (e.g. payroll/attendance events). Gracefully degrades if Firebase is not configured locally.

---

### Feature 7: Admin Hub Dashboard (Navigation Redesign)

- **Description:** Admin panel changed from a **2-tab layout** (Employees + Attendance Report inline) to a **card-based hub** linking to separate modules: Employees, Attendance Report, Payroll, Payments.
- **Key Files Modified/Added:**
  - `lib/app/views/admin_panel_view.dart`
  - `lib/app/widgets/admin_hub_card.dart`
  - `lib/app/views/attendance_report_view.dart` (now standalone)
- **Impact:** Cleaner navigation as the app grows; each module gets its own screen and binding.

---

### Feature 8: Reusable Employee Picker

- **Description:** Shared employee selection screen used by payments, payroll rates, and payroll balance flows.
- **Key Files Modified/Added:**
  - `lib/app/views/employee_picker_view.dart`
  - `lib/app/controllers/employee_picker_controller.dart`
  - `lib/app/routes/route_args.dart`, `app_navigation.dart`
- **Impact:** Consistent UX and less duplicated picker logic across modules.

---

### Feature 9: Payment Enhancements

- **Description:** Payments can be linked to payroll periods; currency dropdown (default **AUD**); employee default currency respected; success feedback improved.
- **Key Files Modified/Added:**
  - `lib/app/views/create_payment_view.dart`
  - `lib/app/controllers/create_payment_controller.dart`
  - `lib/app/core/constants/payment_currencies.dart`
  - Updated payment models/repository
- **Impact:** Payments integrate with payroll workflow and support multi-currency.

---

### Feature 10: Live Clock Duration & Improved Attendance UI

- **Description:** Shows real-time "clocked in for HH:MM:SS" using `current_clock_in_at` and a periodic timer.
- **Key Files Modified/Added:**
  - `lib/app/utils/employee_clock_status.dart`
  - Extended `EmployeeModel` with `currentClockInAt`, `clockedInDurationSeconds`, `defaultCurrencyCode`, `roleId`, `roleName`
- **Impact:** Staff and admins see accurate live clock status.

---

### Feature 11: Phone Number as Login Identifier

- **Description:** Login and employee contact flows prioritize **phone numbers** over email.
- **Key Files Modified/Added:**
  - `lib/app/utils/phone_utils.dart`
  - Updated `login_request_model.dart`, login view, employee views
- **Impact:** Better fit for staff who may not use email regularly.

---

### Feature 12: Employee PIN Reset (Admin)

- **Description:** Admins can reset an employee's PIN from the employee detail screen.
- **Key Files Modified/Added:**
  - `employee_detail_controller.dart` → `requestPinReset()`
  - `employee_remote_datasource.dart` → `POST /v1/employees/{id}/reset-pin`
- **Impact:** Self-service recovery when staff forget their PIN.

---

## 3. Code Differences & Enhancements (Folder/File Level)

### Scale of change

| Metric | Original | Fork |
|---|---|---|
| `lib/` Dart files | ~66 | ~139 |
| New files in fork | — | **74** |
| Removed files | — | **2** (password dialogs) |
| Modified shared files | — | **45** |
| Routes (`AppRoutes`) | 11 | **26** |
| Test files | 7 | **15** |

---

### Backend / Logic changes

| Area | Original | Fork |
|---|---|---|
| **API base URL** | Hardcoded LAN IP `http://192.168.43.200:8000` | Configurable via `--dart-define=API_BASE_URL`, default `https://timesheetbackend.deepdownidea.com` |
| **Tenant/Branch IDs** | Hardcoded in `app_constants.dart` | Removed; derived from login token / `TokenStorage.branchId` |
| **Token storage** | `GetStorage` (plain) | `flutter_secure_storage` + in-memory cache |
| **Auth flow** | `login()` + `verifyUser()` | `loginWithTokens()`, first-login redirect, PIN verify/set, logout clears secure storage |
| **Attendance auth** | Password re-entry (+ default `123456`) | 4-digit PIN verify/set |
| **New repositories** | attendance, auth, payment | + `employee_repository`, `payroll_repository` |
| **New remote datasources** | attendance, auth, payment | + `employee_remote_datasource`, `payroll_remote_datasource` |
| **Routing helpers** | None | `app_navigation.dart`, `route_args.dart` (web-safe navigation) |
| **App lifecycle** | Stateless app widget | Stateful widget with token refresh on resume |

---

### UI / Frontend changes

| Area | Change |
|---|---|
| **Admin panel** | Tabbed (Employees + Attendance inline) → Hub cards linking to separate screens |
| **Attendance report** | Embedded tab → Standalone `AttendanceReportView` with Excel export |
| **Employee management** | Simple tab → Full list + detail profile with edit mode |
| **Payroll** | Did not exist → 8+ new screens |
| **Login** | Similar layout; identifier field now supports phone |
| **Create employee** | Success flow → Dedicated `employee_created_view.dart` |
| **Attendance home** | Basic list → Live duration ticker, PIN dialogs, phone-based subtitles |
| **Removed UI** | Password confirmation + inline change-password dialogs |

---

### Dependencies & Packages

**Added in fork (`pubspec.yaml`):**

| Package | Purpose |
|---|---|
| `firebase_core` ^3.15.2 | Firebase initialization |
| `firebase_messaging` ^15.2.10 | Push notifications |
| `flutter_secure_storage` ^9.2.4 | Secure token storage |
| `dart_jsonwebtoken` ^2.8.4 | JWT expiry parsing for proactive refresh |
| `path_provider_platform_interface` ^2.1.2 | Dev/test support |

**Unchanged core deps:** `dio`, `get`, `get_storage`, `geolocator`, `permission_handler`, `data_table_2`, `excel`, `path_provider`, `share_plus`, `mocktail`

**New documentation (`docs/`):**

- `certificate-pinning.md`
- `fix-plan-fe-v1.md`
- `flutter-commands.md`
- `web-deploy-gcs-cloudflare.md`

---

## 4. Code Quality & Recommendations

### Overall quality assessment

Your friend's code is **generally clean and well-structured**:

- Consistent **GetX** pattern (bindings → controllers → repositories → datasources)
- Good separation of concerns with new modules (payroll, employee)
- Sensible error handling with typed models (`AuthErrorModel`, etc.)
- **8 new test files** covering token storage, navigation, employee detail, rate forms, attendance matrix
- Security-conscious choices (secure storage, removal of hardcoded tenant/branch/password)
- Non-fatal Firebase init (app still works without Firebase config)

---

### Potential issues to review before merging

| Issue | Severity | Details |
|---|---|---|
| **Firebase config required for notifications** | Low | Push notifications silently fail without `google-services.json` / Firebase setup. Not a blocker for core features. |
| **Production API URL baked in as default** | Medium | Fork defaults to `timesheetbackend.deepdownidea.com`. You may want your own `--dart-define` for local/dev builds. |
| **Certificate pinning not implemented yet** | Medium | Documented in `docs/certificate-pinning.md` but not in code — planned hardening, not done. |
| **Silent catch blocks** | Low | Token refresh and Firebase init swallow errors (`catch (_) {}`). Intentional for resilience, but harder to debug. |
| **Large surface area** | Medium | 74 new files means merge conflicts are likely if you've also changed shared files (`auth_controller`, `attendance_controller`, etc.). |
| **Removed password dialogs** | Info | If your backend still expects password-based attendance verification, PIN flow must be supported server-side. |

---

### Merge recommendation

| Area | Recommendation |
|---|---|
| **Payroll module** | Safe to merge if your backend supports payroll APIs |
| **PIN attendance flow** | Merge — clearly better than hardcoded `123456` password |
| **Secure token storage** | Strongly recommended |
| **First-login flow** | Merge if backend sends `must_change_password` |
| **Admin hub redesign** | Merge — cleaner architecture |
| **Firebase notifications** | Merge with Firebase project setup, or disable until configured |
| **`app_constants.dart` base URL** | Review — set your preferred default or always use `--dart-define` |
| **Hardcoded tenant/branch removal** | Merge — your original hardcoded IDs would break multi-tenant use |

**Suggested merge order:**

1. Core infra first (`token_storage`, `auth_interceptor`, `app_constants`)
2. Auth flows (first-login, PIN)
3. Employee management + detail
4. Payroll module
5. Firebase/notifications last

**Files to review carefully for conflicts (both projects modified):**

- `auth_controller.dart`, `auth_repository.dart`, `auth_interceptor.dart`
- `attendance_controller.dart`, `attendance_repository.dart`
- `admin_panel_view.dart`, `employee_management_tab.dart`
- `create_payment_view.dart`, `create_payment_controller.dart`
- `main.dart`, `app_pages.dart`, `app_routes.dart`

---

### Summary verdict

Your friend's fork is a **substantial, production-ready evolution** of your app. It is not just UI polish — it adds payroll, employee admin, PIN auth, secure sessions, and push notifications. The code quality is good and test coverage improved. You should **merge most of it**, but review **API URL defaults**, **Firebase setup**, and **shared-file conflicts** first, especially if you have local changes in shared files like `employee_detail_view.dart`.
