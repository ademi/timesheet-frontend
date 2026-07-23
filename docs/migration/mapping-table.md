# Old → New Mapping Table (Expanded)

Companion to [flutter-migration-impact-study.md](./flutter-migration-impact-study.md).

**Change types:** Added · Removed · Renamed · Modified · Replaced · No Change · Unknown / Needs Backend Clarification  

**Impact levels:** Low · Medium · High · Critical

---

## A. Identity, auth, and session

| Current App Area / Concept | New Platform Concept | Type of Change | Impact Level | Required Flutter Change | Notes |
|---|---|---|---|---|---|
| `GatewayController` + `UserRole.attendance \| admin` | JWT `actor_type` (`tenant_member` \| `contractor`) | Replaced | Critical | Remove portal role picker or demote to deep-link helper; route from `/auth/me/context` | `lib/app/controllers/gateway_controller.dart` |
| `TokenStorage.role` (`user_role`) | Persist `actor_type` + engagement context | Replaced | Critical | Change secure storage keys; migration wipe | `lib/core/services/token_storage.dart` |
| `AuthTokenModel` (access/refresh/`must_change_password`/`branch_id`) | Same tokens + richer claims (`actor_type`, ids, permissions) | Modified | Critical | Parse claims; optional context DTO | `lib/app/data/models/auth/auth_token_model.dart` |
| `POST /v1/auth/login` | Login issues actor-specific JWT | Modified | Critical | Handle contractor engagement list / tenant selection | Spec §4.4 |
| Refresh via `AuthInterceptor` | Refresh bound to `tenant_id`; rotate on switch | Modified | High | Ensure switch-tenant updates both tokens | Spec §4.4 SECURITY |
| `POST /v1/auth/complete_first_login` | Likely retained for password | Unknown / Needs Backend Clarification | Low | Keep until confirmed removed/changed | `FirstLoginController` |
| `POST /v1/auth/verify_pin`, `set_pin` | Removed | Removed | Critical | Delete datasource methods + UI | `AuthRemoteDataSource`, `AppConstants.verifyPinPath` |
| `AuthRepository.verifyPin` / `setPin` | Removed | Removed | Critical | Delete | `auth_repository.dart` |
| Missing | `POST /v1/auth/switch-tenant` | Added | Critical | New auth API + UI | Spec §16.1 |
| Missing | `GET /v1/auth/me/context` | Added | Critical | Session bootstrap | Spec §16.1 |
| Hard split member∩contractor | Enforce 409 `hard_split_violation` | Added | High | UX error handling; no dual tooling | Spec §4.1 |
| `AuthGuard` | Auth + actor + permission guards | Modified | Medium | Extend middleware | `lib/app/routes/middlewares/auth_guard.dart` |
| Platform admin | Keep `platform.admin` | No Change | Low | Out of primary mobile scope unless used | Spec §15 |

---

## B. People: employees → members / contractors / engagements

| Current App Area / Concept | New Platform Concept | Type of Change | Impact Level | Required Flutter Change | Notes |
|---|---|---|---|---|---|
| `EmployeeModel` | Split across tenant_member + contractor + engagement | Replaced | Critical | New models; stop using employee as universal actor | `employee_model.dart` |
| `employee_code` | Not on tenant_members; contractors have profile fields | Removed | High | Remove from forms/UI | Spec §4.2 |
| Employee clock flags (`clockedin`/`clockedout`) | Visit check-in state | Replaced | Critical | Remove from list UIs | — |
| `EmployeeRemoteDataSource` | `tenant_members` + `contractors`/`engagements` APIs | Replaced | Critical | New datasources | Spec §16.2–16.3 |
| `EmployeeRepository` | Multiple repositories | Replaced | Critical | Split | — |
| `EmployeeManagementView` / controller | Tenant members list + contractors/engagements list | Replaced | Critical | New screens | Admin shell label “Employees” obsolete |
| `CreateEmployeeView` / controller (direct Dio `POST /v1/employees`) | Create tenant_member **or** invite contractor engagement | Replaced | Critical | Two flows; fix layering leak | `create_employee_controller.dart` |
| `EmployeeDetailView` | Member detail **or** engagement detail | Replaced | Critical | Engagement status actions | — |
| `EmployeePickerView` | Contractor/engagement picker; visit assignee picker | Replaced | High | New picker args | Used by payments/corrections/rates |
| `POST /v1/employees/{id}/reset-pin` | Removed | Removed | High | Delete | `EmployeeRemoteDataSource.resetEmployeePin` |
| Bulk delete employees | Unknown for members/contractors | Unknown / Needs Backend Clarification | Medium | Confirm tenant_member deactivate vs delete | — |
| Employee org `roleId`/`roleName` | RBAC roles `owner`/`admin`/`supervisor` + contractor role | Modified | High | Role assignment UI for members | Spec §15.1 |
| Missing | Engagement status machine UI | Added | Critical | Invite→…→ended actions | Spec §5.2 |
| Missing | Required doc categories on invite | Added | High | Category multi-select | Spec §5.3 |
| Missing | Consent timestamps / revoke on end | Added | Medium | Show consent state; hide docs when revoked | Spec §5.4 |
| Missing | `POST /contractors/register` | Added | High | Contractor self-registration if in mobile scope | Spec §16.3 |

---

## C. Attendance and time

| Current App Area / Concept | New Platform Concept | Type of Change | Impact Level | Required Flutter Change | Notes |
|---|---|---|---|---|---|
| `AttendanceView` kiosk | Contractor personal visit check-in | Replaced | Critical | New contractor visit UI; delete shared PIN device flow | Spec §23 |
| `AttendanceController` | VisitAttendanceController (new) | Replaced | Critical | Check-in/complete against visit | — |
| `AttendancePinDialog` / set PIN dialog | Removed | Removed | Critical | Delete widgets | — |
| `POST /v1/attendance/clock-in` | `POST /v1/visits/{id}/check-in` | Replaced | Critical | New datasource methods | Spec §16.6 |
| `POST /v1/attendance/clock-out` | `POST /v1/visits/{id}/complete` | Replaced | Critical | Forms gate before complete | Spec §10.3 |
| `AttendanceRequestModel` (employeeId + GPS) | Visit id + GPS body | Modified | Critical | New DTO | — |
| `GET /v1/employees/clocked-in-status` | Visits list / open time entry via visit | Replaced | Critical | Remove from almost all modules that reuse it | Heavily reused today |
| `TimeEntryOut` without visit | `time_entries.visit_id` UNIQUE | Modified | Critical | Model change | Spec §10.1 |
| `GET /v1/attendance/exceptions` | Unknown visit exception queue | Unknown / Needs Backend Clarification | High | Hold corrections redesign | Spec mentions `attendance.adjust` perm |
| `POST /v1/attendance/adjustments` | Admin adjustment APIs (detail TBD) | Modified | High | Confirm actions enum replacement | Current `AdjustmentAction` employee-centric |
| `AttendanceCorrectionsView` / Adjustment | Visit time correction UX | Modified | High | Rewrite when API ready | — |
| `AttendanceReportView` + weekly API | Unknown | Unknown / Needs Backend Clarification | Medium | Weekly report path not in §16 | Direct Dio in controller today |
| Geofence GPS punch | Radius + `informational`/`enforce` | Modified | High | Handle `geofence_rejected`; show informational outside | Spec §10.2 |
| Breaks on time entry | “Keep if still needed” | Unknown / Needs Backend Clarification | Low | Confirm if mobile exposes breaks | Spec §10.1 |

---

## D. Scheduling

| Current App Area / Concept | New Platform Concept | Type of Change | Impact Level | Required Flutter Change | Notes |
|---|---|---|---|---|---|
| `ShiftScheduleView` + widgets | Admin visits board + contractor leave busy | Replaced | High | Major UI rewrite | Spec §11 |
| `ScheduleBoard` / `BoardEmployee` | Visits + contractor availability intersection | Replaced | High | New models | `scheduling/` models |
| Assignments upsert/bulk/delete | Manual `POST /jobs/{id}/visits` + recurrence generate | Replaced | High | New job/visit APIs | Spec §9.3–9.4 |
| `employee-schedules` paths | `contractor_availability_rules` | Renamed | High | Contractor-me + admin views | Spec §11 |
| Scheduling leave | `contractor_leave` (global) | Modified | High | Cross-tenant leave for contractor | — |
| Copy week | Unknown | Unknown / Needs Backend Clarification | Medium | May be replaced by recurrence generate | — |
| Schedule templates | Optional keep | Modified | Medium | Confirm still exposed | Spec §11 |
| `SchedulingPermissions` | Still valid + more perms | Modified | Medium | Expand constants | Spec §15.2 |
| Missing | `GET /contractor-me/timetable` | Added | High | Contractor cross-tenant calendar | Spec §16.7 |
| Missing | Visit overlap errors `visit_overlap` | Added | Medium | Surface 409 on create/generate | Spec §19 |

---

## E. Payroll and payments

| Current App Area / Concept | New Platform Concept | Type of Change | Impact Level | Required Flutter Change | Notes |
|---|---|---|---|---|---|
| Payroll periods CRUD/calculate/close | Removed | Removed | Critical | Delete views/controllers/repo methods | Spec §23 |
| `PayrollSettings` + `PayrollSettingsStorage` | Removed (period candidates) | Removed | High | Delete GetStorage usage | `lib/app/data/services/` |
| Period results / result detail | Removed | Removed | Critical | Delete | — |
| Employee balance | Unknown | Unknown / Needs Backend Clarification | Medium | Confirm if replaced by unpaid/paid visit sums | — |
| Payroll summary report | Unknown | Unknown / Needs Backend Clarification | Medium | Confirm reporting API | — |
| Employee rates (`/payroll/rates/{employeeId}`) | `engagement_rates` | Replaced | High | New screens under engagement | Spec §12.1 |
| `CreatePaymentRequest` employee/period/result | Payment batch from visit ids | Replaced | Critical | New create/post/void flows | Spec §16.8 |
| `PaymentOut` / report / history | Batch + visit payment_status | Replaced | High | New models + contractor `payments.view_own` | — |
| `PayrollMainView` hub | Payments hub (batches) + rates entry | Replaced | High | Shell IA change | — |
| Missing | `payment_status` on visit | Added | High | Filters unpaid visits | Spec §9.4 |
| Missing | Batch `draft\|posted\|void` | Added | High | Status UI | Spec §12.2 |

---

## F. Clients, jobs, forms, documents (new)

| Current App Area / Concept | New Platform Concept | Type of Change | Impact Level | Required Flutter Change | Notes |
|---|---|---|---|---|---|
| None | Clients / sites / contacts | Added | High | Full module | Spec §6 |
| None | Client documents | Added | Medium | Via documents API | Spec §6.4 |
| None | Client invite tokens (create) | Added | Medium | Admin create invite; show raw token once | Spec §6.5 |
| None | Public invite acknowledge | Added | Low | Probably not Flutter mobile | Confirm web |
| None | Form templates + schema_json | Added | High | Builder (maybe web) + runtime renderer (mobile) | Spec §8 |
| None | Job form catalog | Added | High | Attach templates to job | — |
| None | Visit form requirements + submissions | Added | Critical | Required for complete | Spec §8.3, §10.3 |
| None | Jobs standing/ad_hoc | Added | Critical | CRUD + constraints UX | Spec §9.1 |
| None | Recurrence rules + generate | Added | High | RRULE UX; handle partial errors | Spec §9.3 |
| None | Visits + tasks | Added | Critical | Core screens | Spec §9.4–9.6 |
| None | Documents signed URL upload/download | Added | High | New service | Spec §7, §16.9 |
| None | Document scan_status / consent ACL | Added | High | UX for pending/blocked/revoked | Spec §7.3 |

---

## G. Branches, shell, notifications, packages

| Current App Area / Concept | New Platform Concept | Type of Change | Impact Level | Required Flutter Change | Notes |
|---|---|---|---|---|---|
| `BranchGatewayView` + `BranchModel` | Branches with point+radius; jobs reference branch XOR site | Modified | Medium | Update model; reassess mandatory branch gate for contractors | Spec §9.2 |
| Branch id injected into most repos | Tenant JWT primary; branch less universal | Modified | High | Audit `_resolveBranchId` patterns | Scheduling/payroll/attendance repos |
| `AdminShellRoutes` 6 destinations | New IA (clients, contractors, jobs, …) | Replaced | High | Rewrite rail | `admin_shell_routes.dart` |
| `AdminPanelView` hub cards | New hub | Modified | Medium | New cards | — |
| `PushNotificationService` → `/v1/notifications/devices` | Same + new event types | Modified | Medium | Handle new events; ignore unknown | Spec §14 |
| `geolocator` / permissions | Visit GPS | No Change | Low | Keep | — |
| `excel` / share exports | New reports if any | Unknown / Needs Backend Clarification | Low | Keep until reports confirmed | — |
| File/image picker packages | Documents + form file fields | Added | High | Add dependencies | Not in pubspec today |
| Billing accounts UI | SaaS billing | Added | Low | Likely out of mobile V1 | Spec §13 |
| Email/SMS | Stubbed server-side | No Change | Low | No Flutter provider work | Spec non-goal |

---

## H. Tests mapping

| Current App Area / Concept | New Platform Concept | Type of Change | Impact Level | Required Flutter Change | Notes |
|---|---|---|---|---|---|
| Payment controller/view/model tests | Payment batch tests | Replaced | Medium | Rewrite | `test/app/controllers/create_payment_*` etc. |
| Employee detail / rate form tests | Member/engagement/rate tests | Replaced | Medium | Rewrite | — |
| Auth datasource tests (incl PIN) | Auth without PIN + switch-tenant | Modified | Medium | Update | — |
| `attendance_report_matrix_test` | Unknown | Unknown / Needs Backend Clarification | Low | Likely delete | — |
| Shift schedule cell test | Visit cell/widget tests | Replaced | Low | Rewrite | — |
| Token storage tests | New keys/claims | Modified | Medium | Extend | — |

---

## Legend: files most frequently implicated

| Path | Why |
|------|-----|
| `lib/app/routes/app_routes.dart` / `app_pages.dart` | Full route redesign |
| `lib/app/views/shell/admin_shell_routes.dart` | IA redesign |
| `lib/core/services/token_storage.dart` | Session claims |
| `lib/app/data/models/attendance/employee_model.dart` | Universal actor removal |
| `lib/app/data/datasources/remote/*.dart` | All seven datasources |
| `lib/app/controllers/*` | All twenty-seven controllers |
| `lib/core/constants/app_constants.dart` | Path constants |
