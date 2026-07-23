# Flutter App Migration Impact Study

**Product:** Rostiq Flutter client (`rostiq` / `timesheet-frontend`)  
**Compared against:** `docs/2026-07-22-contractor-client-job-design (1).md`  
**Study date:** 2026-07-23  
**Architecture today:** GetX (routing, DI, reactive controllers) + Dio remote datasources + repository layer  
**Back-compat (per spec):** Not required. Prefer clear breaks over dual-running old employee clocking.

**Companion docs in this folder:**
- [mapping-table.md](./mapping-table.md) — expanded mapping rows
- [clarification-questions.md](./clarification-questions.md) — questions for backend/product
- [development-backlog.md](./development-backlog.md) — suggested backlog

---

## 1. Executive Summary

The current Flutter app is built around an **employee workforce model**: shared-device PIN kiosk clock-in/out, branch-scoped admin tools for employees, shift assignment boards, **payroll periods** (calculate/close), and employee-linked payments.

The new platform replaces that model with a **service-provider tenant + global contractor + tenant-owned client** domain:

- Staff become **tenant members** (no clocking, no PIN).
- Field workers become **contractors** linked via **engagements**.
- Work becomes **Jobs → Visits → Tasks**, with time entries **bound to a visit**.
- Money moves from **payroll periods/results** to **engagement rates + visit payment batches**.
- Auth gains **actor types**, **tenant switch**, and a much larger RBAC surface.

**Verdict:** This is an **Extra Large / P0 platform rewrite** of the Flutter client, not an incremental feature add. Approximately **~28 routes, ~27 controllers, 7 datasources/repos, and most views/models** are affected. Reusable pieces are limited mainly to shell/responsive layout, Dio/auth interceptors, branch listing patterns, GPS utilities, Excel export helpers, and push registration plumbing.

**Recommended approach:** Treat V1 as a **greenfield domain module set** inside the existing GetX shell, deprecate/remove the employee–PIN–period stack, and gate rollout behind API readiness + feature flags. Do not attempt dual-running old and new clocking flows (spec explicitly rejects back-compat).

---

## 2. Source Documentation Reviewed

| Document | Notes |
|----------|-------|
| `docs/2026-07-22-contractor-client-job-design (1).md` | Normative domain design for DB + backend APIs/workflows |
| Companion referenced in spec | `2026-07-22-contractor-client-job-approaches.md` — **not present in this Flutter repo** (Unknown / Needs Clarification if needed for UX alternatives) |

**Spec scope reminders relevant to Flutter:**

- Goals: tenants, tenant_members, contractors, clients (no login), jobs/visits/tasks, visit GPS check-in/out, GCS documents, visit-based payments, stubbed email/SMS.
- Non-goals for V1 backend: client accounts, employee PIN kiosk, free-floating time entries, payroll periods, real email/SMS, **frontend/UX work** (so mobile UX is not specified in detail — Flutter team must confirm product UX separately).
- Explicit removals: employees workforce clocking, PIN punch, time entry without `visit_id`, payroll periods calculate/close.

---

## 3. Current Flutter App Overview

### 3.1 Stack and layout

| Area | Implementation |
|------|----------------|
| Package | `rostiq` (`pubspec.yaml` v1.0.0+2) |
| State / nav / DI | GetX (`get`) |
| HTTP | Dio (`ApiClient`, `AttendanceApiClient`) + `AuthInterceptor` |
| Tokens | `TokenStorage` (`lib/core/services/token_storage.dart`) via `flutter_secure_storage` |
| Local prefs | `GetStorage` for `PayrollSettingsStorage` only |
| GPS | `geolocator` + `permission_handler` |
| Push | `firebase_messaging` → `PushNotificationService` |

**Layering:**

```text
Views → Controllers (GetxController) → Repositories → RemoteDataSources (Dio) → API
Bindings wire DI per route / module (*ModuleBinding.ensureDependencies)
```

### 3.2 Module map (as implemented)

| Module | Key paths | Purpose today |
|--------|-----------|---------------|
| Gateway / portal role | `gateway_view.dart`, `GatewayController` | Client-side `UserRole.attendance \| admin` |
| Auth | `auth_*`, `first_login_*` | Login, refresh, logout, first-login password |
| Branches | `branch_gateway_*`, `BranchRepository` | Post-login branch selection |
| Attendance kiosk | `attendance_view.dart`, `AttendanceController` | Shared-device PIN + GPS clock |
| Employees | `employee_*`, `CreateEmployeeController` | CRUD-ish staff/workforce management |
| Attendance admin | report / corrections / adjustment views | Exceptions, adjustments, weekly report |
| Scheduling | `shift_schedule_*`, `SchedulingRepository` | Employee board, assignments, leave, templates |
| Payroll | `payroll_*`, `PayrollRepository` | Periods, rates, balance, summary |
| Payments | `payment_*`, `PaymentRepository` | Create payment, report, history |

### 3.3 Routes (from `AppRoutes` / `app_pages.dart`)

Protected by `AuthGuard` except gateway/login/first-login. Initial route: `/gateway`.

| Route constant | Path | Primary view |
|----------------|------|--------------|
| `gateway` | `/gateway` | `GatewayView` |
| `login` | `/login` | `LoginView` |
| `firstLogin` | `/first-login` | `FirstLoginView` |
| `home` | `/home` | `AttendanceView` (kiosk) |
| `adminBranchGateway` | `/admin/branches` | `BranchGatewayView` |
| `adminPanel` | `/admin-panel` | `AdminPanelView` |
| `adminEmployees` | `/admin/employees` | `EmployeeManagementView` |
| `employeeDetail` | `/admin/employees/detail` | `EmployeeDetailView` |
| `createEmployee` | `/create-employee` | `CreateEmployeeView` |
| `createEmployeeSuccess` | `/create-employee/success` | `EmployeeCreatedView` |
| `employeePicker` | `/employees/pick` | `EmployeePickerView` |
| `adminAttendanceReport` | `/admin/attendance-report` | `AttendanceReportView` |
| `adminAttendanceCorrections` | `/admin/attendance-corrections` | `AttendanceCorrectionsView` |
| `adminAttendanceAdjustment` | `/admin/attendance-adjustment` | `AttendanceAdjustmentView` |
| `adminShiftSchedule` | `/admin/shift-schedule` | `ShiftScheduleView` |
| `paymentMain` … `paymentHistory` | `/payments/*` | Payment views |
| `payrollMain` … `payrollSummaryReport` | `/payroll/*` | Payroll views |

Admin wide layout rail (`AdminShellRoutes`): Employees → Report → Corrections → Schedule → Payroll → Payments.

### 3.4 Auth and roles (current)

1. Gateway stores portal role in `TokenStorage` (`user_role`: `admin` / `attendance`) — **not** a JWT claim.
2. Login → tokens (+ optional `branch_id`) → first-login if `must_change_password` → branch gateway.
3. Branch select → admin panel **or** kiosk home based on portal role.
4. JWT `permissions` used today mainly for scheduling (`scheduling.read` / `scheduling.manage` in `SchedulingPermissions`).
5. PIN flows: `POST /v1/auth/verify_pin`, `set_pin`, employee `reset-pin`.

### 3.5 Dominant domain object

`EmployeeModel` (`lib/app/data/models/attendance/employee_model.dart`) is the universal actor across clock status, lists, pickers, rates, payments, scheduling board rows, and reports. Fields include `employee_code`, clock flags, `branch_id`, org `role_id`/`role_name`.

### 3.6 Remote API surface in app today

Datasources under `lib/app/data/datasources/remote/`:

- `AuthRemoteDataSource` — login/refresh/logout/first-login + **PIN**
- `AttendanceRemoteDataSource` — employees clock status, clock-in/out, exceptions, adjustments
- `EmployeeRemoteDataSource` — employees CRUD-ish, time entries, PIN reset, bulk delete
- `PayrollRemoteDataSource` — rates/periods/calculate/close/results/balance/summary
- `PaymentRemoteDataSource` — payments create/report/history
- `SchedulingRemoteDataSource` — board/templates/assignments/leave/employee-schedules/copy-week
- `BranchRemoteDataSource` — `GET /v1/branches`

---

## 4. New Platform Concepts Summary

| Concept | Meaning (from design spec) | Flutter implication |
|---------|----------------------------|---------------------|
| **Tenant** | Paying service-provider company | Existing tenant JWT context remains; billing_accounts added server-side |
| **Tenant member** | Admin/staff; does **not** clock in | Replaces employee admin identity for staff; no PIN |
| **Contractor** | Global profile; works via engagements | New primary field-worker identity; own app flows |
| **Engagement** | Tenant ↔ contractor lifecycle | Invite/accept/docs/approve/activate/suspend/end UI |
| **Client** | Tenant-owned artifact (no login) | New CRM-like admin module; public invite is web/token (app may create invites only) |
| **Job** | `standing` or `ad_hoc` work container | New admin module; standing uniqueness per client |
| **Visit** | One scheduled occurrence; **exactly one** contractor | Core scheduling + contractor work unit |
| **Task** | Checklist on visit | Contractor + admin task toggle UI |
| **Forms** | Templates → job catalog → visit requirements → submissions | New forms engine UI (dynamic fields + file) |
| **Documents** | GCS via signed URLs; consent-gated profile docs | New upload/download flows; no current Flutter GCS layer |
| **Visit time entry** | One time entry per visit; GPS check-in/complete | Replaces free-floating employee clock |
| **Contractor schedule** | Availability + leave; does **not** create visits | Retarget scheduling from employees |
| **Engagement rates** | Hourly rate on engagement | Replaces employee payroll rates |
| **Payment batches** | Batch completed unpaid visits → post/void | Replaces period-centric payments |
| **Actor type** | `tenant_member` \| `contractor` (+ platform admin) | Hard split; drives navigation trees |
| **Switch tenant** | Contractor selects engagement tenant | New auth UX + token rotation |

---

## 5. Gap Analysis

### 5.1 New concepts that must be added

| Concept | Gap vs current app |
|---------|-------------------|
| `actor_type` / `contractor_id` / `tenant_member_id` JWT claims | Not read in `TokenStorage` today |
| `POST /v1/auth/switch-tenant`, `GET /v1/auth/me/context` | Missing |
| Contractor registration / profile (`/contractors`, `/contractor-me`) | Missing |
| Engagements lifecycle APIs + UI | Missing |
| Clients, sites, contacts, client docs, invite creation | Missing |
| Form templates, catalog, visit submissions | Missing |
| Jobs, recurrence rules, generate visits, tasks | Missing |
| Visit check-in / complete (replace clock-in/out) | Missing |
| Documents signed upload/finalize/download | Missing |
| Contractor timetable / availability / leave (cross-tenant) | Missing (employee leave/schedules exist instead) |
| Engagement rates + payment batches | Missing (employee rates + period payments exist instead) |
| Expanded RBAC permission constants | Only scheduling perms encoded today |
| Public client invite acknowledge | Spec is public web-token; **Unknown** if Flutter hosts any public flow |

### 5.2 Existing concepts that will be renamed / replaced

| Current | New | Notes |
|---------|-----|-------|
| `employees` (staff + workforce dual use) | `tenant_members` (staff) + `contractors`/`engagements` (workforce) | Split, not simple rename |
| Employee rates (`/payroll/rates/{employeeId}`) | Engagement rates | Different parent entity |
| Employee schedules / assignments board | Visits board + contractor availability | Different generation model |
| Clock-in/out on employee | Visit check-in/complete | Requires visit_id |
| Portal `UserRole.attendance \| admin` | JWT `actor_type` | Client-side role picker becomes obsolete or secondary |
| Payments tied to employee/period/result | Payment batches of visits | Model rewrite |

### 5.3 Existing concepts that will be removed

| Concept | Spec reference | Flutter blast radius |
|---------|----------------|----------------------|
| Employee PIN kiosk (`/home`, PIN dialogs, verify/set/reset PIN) | §23 Explicit removal | Critical |
| Free-floating time entries without visit | §10, §23 | Critical |
| Payroll periods calculate/close/results | §12.2, §23 | Critical |
| `employee_code` workforce identity | §4.2, §23 | High |
| Employee as clocking actor | Goals/non-goals | Critical |
| Polygon-only geofence for punch (if any client assumption) | §9.2 | Medium (app already GPS point-based; branch model may change) |
| Client approval workflows | Non-goal | N/A (not implemented) |

### 5.4 Existing concepts that change behavior

| Concept | Change |
|---------|--------|
| Login session | Must surface engagements / actor context; contractors may need tenant selection |
| Branch selection | Still relevant for jobs (`branch_id` XOR `client_site_id`); less central as “all APIs scoped only by branch” |
| Attendance corrections | Retarget to visit time entries / `attendance.adjust` — contract **Unknown / Needs Clarification** |
| Weekly attendance report | Likely visit/hours based — **Unknown** report APIs |
| Scheduling board | From employee assignment grid → visits + leave busy signals |
| Geofence | Radius + `informational` \| `enforce`; verdict storage |
| Notifications | New event types; FCM may continue; email/SMS stubbed server-side |
| Permissions | Large new key set; shell destinations must gate by perm + actor |

### 5.5 Data model / API / UX / nav / storage / breaking changes

| Category | Summary |
|----------|---------|
| Data models | Replace `EmployeeModel`-centric DTOs with tenant_member, contractor, engagement, client, job, visit, task, form, document, payment_batch models |
| API contracts | Most `/v1/employees`, `/v1/attendance/clock-*`, `/v1/payroll/periods*`, PIN routes become obsolete; new `/jobs`, `/visits`, `/engagements`, `/clients`, documents, payment-batches |
| UI/UX | Two products in one app (or two shells): **Tenant admin console** and **Contractor field app** |
| Navigation | Remove kiosk home & payroll period tree; add clients/jobs/visits/engagements/docs; contractor home = visits/timetable |
| Permissions | Expand beyond `SchedulingPermissions` |
| Local storage | Drop payroll settings cache; add actor/engagement/tenant-switch persistence; invalidate all sessions on cutover |
| Breaking | Spec: **no back-compat**; fresh domain. App stores must force re-login / clear secure storage |
| Obsolete areas | Entire PIN kiosk module; payroll periods/settings/results/balance; employee-centric payment create; employee board assignment overrides as visit creators |

---

## 6. Detailed Impact Analysis

### 6.1 Affected modules / features

| Module | Impact | Action |
|--------|--------|--------|
| Gateway / `UserRole` | Critical | Replace with actor-aware post-login routing |
| Auth (+ first login) | Critical | Add context, switch-tenant, claim parsing |
| Attendance kiosk | Critical | **Remove** or replace with contractor visit check-in |
| Employees | Critical | Split → tenant members + contractors/engagements |
| Attendance report/corrections/adjustment | High | Redesign against visit time entries |
| Shift schedule | High | Replace employee board with visits/availability |
| Payroll periods/settings/results/balance/summary | Critical | **Remove**; replace with rates + batches |
| Payments (employee/period) | Critical | Replace with payment batches |
| Branches | Medium | Keep list; update geofence fields if API changes |
| Push notifications | Medium | New event handling; device register may stay |
| Responsive admin shell | High | New destinations: Clients, Contractors, Jobs, Visits, Payments, Members |

### 6.2 Affected screens (views)

**Remove or fully replace (Critical):**

- `attendance_view.dart` (+ PIN dialogs/widgets)
- `create_employee_view.dart`, `employee_created_view.dart`, `employee_management_view.dart`, `employee_detail_view.dart`, `employee_picker_view.dart`
- `payroll_main_view.dart`, `payroll_periods_view.dart`, `payroll_settings_view.dart`, `payroll_period_detail_view.dart`, `payroll_period_results_view.dart`, `payroll_result_detail_view.dart`, `payroll_summary_report_view.dart`, `employee_balance_view.dart`
- `employee_rates_view.dart`, `employee_rate_form_view.dart` (rebuild as engagement rates)
- `create_payment_view.dart`, `payment_main_view.dart`, `payments_report_view.dart`, `employee_payment_history_view.dart` (rebuild around batches/visits)

**Heavy rewrite (High):**

- `gateway_view.dart`, `login_view.dart`, `branch_gateway_view.dart`, `admin_panel_view.dart`
- `shift_schedule_view.dart` + `lib/app/views/widgets/shift_schedule_*.dart`
- `attendance_report_view.dart`, `attendance_corrections_view.dart`, `attendance_adjustment_view.dart`

**Likely keep with light changes (Low–Medium):**

- `first_login_view.dart` (if password policy unchanged — confirm)
- Shell: `admin_shell.dart`, `responsive_scaffold.dart`, `two_pane.dart` (destination content changes)

**New screens required (examples):**

- Contractor: engagement picker / switch tenant; my visits; visit detail (tasks/forms/check-in/complete); timetable; availability/leave; profile docs upload; my payments
- Admin: tenant members; contractors & engagements; clients/sites/contacts/docs/invites; form templates; jobs (standing/ad-hoc); recurrence generate; visits board/detail; unpaid visits → payment batch; document viewers

### 6.3 Affected models

Under `lib/app/data/models/`:

| Domain folder | Impact |
|---------------|--------|
| `auth/` (`AuthTokenModel`, PIN verify/set models, login) | Critical — extend token/context; remove PIN models |
| `attendance/` (`EmployeeModel`, clock request/response, exceptions, adjustments, time entries, report) | Critical — reshape or delete |
| `payroll/` (periods, results, settings, rates, balance, summary) | Critical — delete periods/results/settings/balance; rebuild rates |
| `payment/` | Critical — batch models replace create/report employee shapes |
| `scheduling/` | High — board/employee/assignment → visit/availability models |
| `branch/` | Medium — add `location_geog` / `geofence_radius_m` if returned |

### 6.4 Affected services / APIs

| Datasource | Impact |
|------------|--------|
| `auth_remote_datasource.dart` | Add switch-tenant, me/context; remove PIN endpoints |
| `attendance_remote_datasource.dart` | Replace clock-in/out with visit check-in/complete; retarget adjustments |
| `employee_remote_datasource.dart` | **Obsolete** → tenant_members + contractors datasources |
| `payroll_remote_datasource.dart` | Remove periods APIs; engagement rates only |
| `payment_remote_datasource.dart` | Payment batches APIs |
| `scheduling_remote_datasource.dart` | Retarget paths; contractor-me timetable |
| `branch_remote_datasource.dart` | Possibly field additions |
| **New** | clients, jobs/visits, engagements, documents, forms datasources |

Also: `CreateEmployeeController` and `AttendanceReportController` call Dio **directly** (bypass repository) — must be cleaned up in migration.

### 6.5 Affected repositories / “use cases”

No formal use-case layer today (controllers call repositories). All 7 repositories are impacted:

- `AuthRepository`, `AttendanceRepository`, `EmployeeRepository` (retire), `PayrollRepository`, `PaymentRepository`, `SchedulingRepository`, `BranchRepository`

Controllers effectively encode use cases — all 27 controllers need rewrite, retire, or split.

### 6.6 Affected state (controllers)

| Controllers | Disposition |
|-------------|-------------|
| `AttendanceController`, PIN-related UI state | Remove |
| `EmployeeManagementController`, `CreateEmployeeController`, `EmployeeDetailController`, `EmployeePickerController` | Replace with members/contractors/engagements controllers |
| All `Payroll*` + `EmployeeRates*` + `EmployeeBalance*` | Remove / replace |
| `CreatePaymentController`, `PaymentMainController`, `PaymentsReportController`, `EmployeePaymentHistoryController` | Replace with batch flows |
| `ShiftScheduleController` | Rewrite for visits |
| `GatewayController`, `AuthController`, `BranchGatewayController` | Rewrite for actor_type |
| `AttendanceReportController`, `AttendanceCorrectionsController`, `AttendanceAdjustmentController` | Rewrite pending API |

### 6.7 Forms and validation

| Current forms | Impact |
|---------------|--------|
| Login / first-login password (`password_validation.dart`) | Keep likely |
| Create/edit employee | Replace with tenant_member + invite contractor |
| Employee rate form | Engagement rate form |
| Create payment (employee/period/result) | Select unpaid visits → batch |
| Attendance adjustment | Visit time correction form |
| **New** | Client/site/contact forms; job create; recurrence RRULE; form template builder; dynamic form submission renderer; document upload metadata; engagement invite categories |

### 6.8 Routing / navigation

- `AppRoutes`, `app_pages.dart`, `AdminShellRoutes`, `route_args.dart`, `app_navigation.dart` all need redesign.
- `AuthGuard` remains, but post-auth redirect matrix grows (member vs contractor; engagement status gates).
- Route args for employee/payroll become obsolete; need visit/job/engagement/client args.

### 6.9 Tests

Under `test/`:

| Area | Files (examples) | Impact |
|------|------------------|--------|
| Payments | `create_payment_*`, `payments_report_*`, `payment_models_test`, payment datasource test | Rewrite |
| Employee | `employee_detail_controller_test`, rates navigation/form tests | Rewrite/remove |
| Auth | `auth_remote_datasource_test` | Extend; remove PIN cases |
| Token / nav / responsive | token_storage, app_navigation, route_args, responsive_qa | Update for new claims/routes |
| Scheduling widget | `shift_schedule_cell_test` | Rewrite |
| Attendance matrix | `attendance_report_matrix_test` | Likely obsolete |

**Coverage gap:** Almost no tests for attendance kiosk, payroll periods, employees list — migration should add tests for new critical paths, not only port old ones.

### 6.10 Dependencies / packages

| Package | Likely change |
|---------|---------------|
| `get`, `dio`, `flutter_secure_storage`, `dart_jsonwebtoken` | Keep; extend JWT claim usage |
| `geolocator`, `permission_handler` | Keep for visit check-in/complete |
| `excel`, `share_plus`, `path_provider` | Keep for exports if new reports exist |
| `firebase_*` | Keep; map new notification events |
| `get_storage` | Payroll settings may go away — confirm if still needed |
| **Likely new** | File picker / image picker for docs & form file fields; URL launcher for signed downloads; maybe `rrule` package if client-side recurrence preview; MIME helpers |
| **Unknown** | Map/place picker for client sites / job pins — product decision |

### 6.11 Risks and unknowns (summary)

See §10. Highest unknowns: final OpenAPI shapes, contractor vs admin UX packaging (one app vs flavors), attendance adjustment/report replacements, whether Flutter handles public client invite pages, billing UI scope, and form-template builder complexity.

---

## 7. Old-to-New Mapping Table

> Full expanded table: [mapping-table.md](./mapping-table.md)

| Current App Area / Concept | New Platform Concept | Type of Change | Impact Level | Required Flutter Change | Notes |
|---|---|---|---|---|---|
| `EmployeeModel` / `/v1/employees` | `tenant_members` + `contractors` + `engagements` | Replaced | Critical | Split modules, models, APIs, screens | Spec §4, §5, §16.2–16.3 |
| PIN kiosk `/home` + verify/set/reset PIN | Removed (visit check-in by contractor JWT) | Removed | Critical | Delete kiosk + PIN datasources/UI | Spec §23 |
| `POST /attendance/clock-in\|out` | `POST /visits/{id}/check-in` + `/complete` | Replaced | Critical | New visit attendance flow + GPS | Spec §10, §16.6 |
| Free-floating `time_entries` by employee | `time_entries.visit_id` UNIQUE | Modified | Critical | Models/repos/corrections | Spec §10.1 |
| `UserRole.attendance\|admin` gateway | JWT `actor_type` | Replaced | Critical | Post-login routing from `/auth/me/context` | Spec §4.4 |
| `TokenStorage` role/branch only | + actor, contractor/member ids, engagement/tenant switch | Modified | Critical | Extend secure storage + JWT parse | Spec §3.1, §4.4 |
| Payroll periods / calculate / close / results | Removed; payment batches | Removed / Replaced | Critical | Delete payroll period UI; build batches | Spec §12, §23 |
| Employee payroll rates | `engagement_rates` | Renamed / Replaced | High | New parent id = engagement | Spec §12.1 |
| Employee balance / period summary | Unknown / visit payment views | Unknown / Needs Backend Clarification | High | Confirm contractor/admin reporting APIs | Not fully specified for Flutter |
| Create payment (employee/period/result) | Payment batches of unpaid visits | Replaced | Critical | New create/post/void UX | Spec §12.2, §16.8 |
| Shift board employee assignments | Visits (+ recurrence generate) | Replaced | High | Rewrite schedule module | Spec §9, §11 |
| `employee-schedules` + leave | `contractor_availability` + `contractor_leave` | Renamed / Modified | High | Contractor-me APIs; admin busy view | Spec §11 |
| Attendance exceptions/adjustments | `attendance.adjust` on visit entries | Modified | High | Confirm API payloads | Spec lists perm; endpoints sparsely detailed |
| Weekly attendance report | Unknown visit/hours report | Unknown / Needs Backend Clarification | Medium | Hold UI until API exists | Not in §16 API list |
| Branches list + branch scope | Branches + radius geofence; job location XOR site | Modified | Medium | Model fields; less universal branch filter | Spec §9.1–9.2 |
| Admin shell Employees rail | Members / Contractors / Clients / Jobs | Replaced | High | `AdminShellRoutes` redesign | — |
| Scheduling permissions only | Large RBAC key set | Added / Modified | High | Central permissions constants + guards | Spec §15 |
| Push device register | + new engagement/visit events | Modified | Medium | Handle new event types if pushed | Spec §14 |
| Documents | GCS signed URL documents module | Added | High | New datasource + upload UX | Spec §7, §16.9 |
| Clients / sites / contacts | Client artifacts module | Added | High | New feature module | Spec §6 |
| Forms templates/submissions | Forms module | Added | High | Dynamic form renderer | Spec §8 |
| Jobs / visits / tasks / recurrence | Jobs module | Added | Critical | Core domain UI | Spec §9 |
| Engagements lifecycle | Engagements module | Added | Critical | Status machine UI | Spec §5 |
| `switch-tenant` | Contractor multi-tenant session | Added | Critical | Auth + token rotation UX | Spec §4.4 |
| Billing accounts | SaaS billing | Added | Low–Medium | Likely out of mobile V1 — confirm | Spec §13; frontend non-goal |
| Public client invite acknowledge | Public token pages | Added | Low | Probably web; confirm if in Flutter web | Spec §6.5 |
| Geofence polygon (backend) | Point + radius; enforce/informational | Modified | Medium | Surface verdict/errors (`geofence_rejected`) | Spec §9.2, §19 |
| First-login password | Likely retained | No Change / Unknown | Low | Confirm still required for members/contractors | — |
| `AuthGuard` | Still valid | Modified | Medium | Actor-aware redirects | — |

---

## 8. Required Flutter Changes

### 8.1 Models and Entities

**Remove / stop using:** PIN request/response models; period/result/balance/settings payroll models; employee-centric payment request shapes; board employee assignment models as visit generators.

**Add domain packages (suggested folders):**

```text
lib/app/data/models/
  auth/          # extend AuthTokenModel + SessionContextModel
  tenant_member/
  contractor/
  engagement/
  client/        # client, site, contact, invite
  job/           # job, visit, task, recurrence
  form/
  document/
  payment/       # batch, batch visit line
  scheduling/    # timetable, availability, leave (retargeted)
  branch/        # radius fields
```

**Recommendation:** Keep API DTOs (`*Dto` / `*Response`) separate from UI view-state; map in repositories. Encode engagement/visit status enums matching spec machines.

### 8.2 API Services

- Extend `AppConstants` with new path constants; remove PIN and obsolete payroll/employee clock paths when backend cuts over.
- Add remote datasources: `EngagementRemoteDataSource`, `ContractorRemoteDataSource`, `ClientRemoteDataSource`, `JobRemoteDataSource`, `VisitRemoteDataSource`, `FormRemoteDataSource`, `DocumentRemoteDataSource`, `PaymentBatchRemoteDataSource`, `TenantMemberRemoteDataSource`.
- Refactor `AuthRemoteDataSource` for `switch-tenant` + `me/context`.
- Replace attendance clock methods with visit check-in/complete.
- Stop controller-level raw Dio calls (`CreateEmployeeController`, `AttendanceReportController` pattern).

### 8.3 Repositories and Use Cases

- Mirror datasources 1:1 with repositories for V1 (consistent with current style).
- Optional later: extract use cases for engagement transitions and visit complete (complex validation).
- Centralize branch/tenant resolution; contractors may omit branch for some APIs.

### 8.4 State Management

- Remain on GetX for consistency unless team explicitly chooses a rewrite (not required for domain migration).
- Introduce module bindings: `ContractorModuleBinding`, `ClientsModuleBinding`, `JobsModuleBinding`, etc.
- Session controller (new) owning `actorType`, engagements, current tenant — single source for shell + guards.
- Prefer fewer “god” controllers; visit detail may need dedicated controller for tasks/forms/GPS.

### 8.5 Screens and UI Components

**Admin shell destinations (proposed):** Dashboard/Hub · Clients · Contractors/Engagements · Jobs/Visits · Schedule/Timetable · Payments (batches) · Team (tenant members) · Forms · Settings/Branches.

**Contractor shell (proposed):** Today/Upcoming visits · Visit detail · Timetable · Documents · Payments (own) · Switch tenant / profile.

**Shared components to build:** status chips for engagement/visit; GPS check panel; dynamic form renderer; document upload tile; unpaid visit multi-select; engagement action buttons (approve/activate/suspend/end).

### 8.6 Navigation and Routing

- Rebuild `AppRoutes` / `app_pages.dart`.
- Replace `AdminShellRoutes` destination lists.
- Auth redirect:
  - `tenant_member` → branch (if still required) → admin shell
  - `contractor` without tenant → engagement/tenant picker → contractor shell
  - `pending_docs` / `invited` → onboarding gates before visit ops
- Deep links: visit detail, engagement invite accept (**confirm**).

### 8.7 Local Storage and Cache

| Current | Migration |
|---------|-----------|
| Access/refresh tokens | Keep; clear on cutover |
| `branch_id` / `branch_name` | Keep if still used; validate against new APIs |
| `user_role` portal | Replace with `actor_type` + selected engagement id |
| `payroll_settings` GetStorage | Delete on upgrade |
| New | Cache `SessionContext`; optional last tenant id for contractors |

**Cutover rule:** On first launch against new backend, wipe secure storage and force login (no token shape compatibility assumed).

### 8.8 Authentication and Authorization

- Parse JWT: `actor_type`, `contractor_id` / `tenant_member_id`, `tenant_id`, `permissions`.
- Implement switch-tenant → persist rotated tokens; revoke old refresh (server-side).
- Enforce hard-split UX: never show member + contractor tooling for same session.
- Expand permission helper beyond `SchedulingPermissions` (e.g. `AppPermissions` map of §15.2 keys).
- Map API errors: `wrong_actor_type`, `engagement_inactive`, `hard_split_violation`, etc. (`§19`).

### 8.9 Forms and Validation

- Build validators for client contacts (email or phone required), job location XOR, recurrence window caps (UX copy), file types/size for documents (align with 20 MiB + allowlist).
- Dynamic form submission: required fields + file `document_id` scan status messaging.
- Engagement invite: required doc categories multi-select.

### 8.10 Tests

- Delete obsolete PIN/period/employee payment tests as code is removed.
- Add priority tests: session context parsing; switch-tenant storage; engagement status actions; visit check-in GPS error handling; payment batch selection rules; form required gate; permission-gated navigation.
- Widget tests for visit detail and dynamic forms.
- Integration (golden path) against staging mock or http mocks (`mocktail` already in use).

---

## 9. Migration Plan

### Phase 1: Discovery and Confirmation

**Goal:** Freeze contracts before mass Flutter coding.

- Walk through [clarification-questions.md](./clarification-questions.md) with backend/product.
- Obtain OpenAPI (or draft) for §16 endpoints; confirm error catalog §19.
- Confirm app packaging: single app dual-shell vs two flavors vs admin-web + contractor-mobile.
- Confirm which V1 screens are in mobile vs web-only (clients, form builder, billing).
- Confirm attendance adjustment/report replacements.
- Confirm notification payloads for FCM.
- Spike: login → me/context → switch-tenant against staging.

**Exit criteria:** Signed-off API contract + UX scope matrix (In / Out / Later).

### Phase 2: Architecture Preparation

- Create feature folder scaffolding + empty datasources/repos/bindings.
- Extend `TokenStorage` / session models without flipping production traffic.
- Add `AppPermissions` constants; feature flags remote or compile-time (`dart-define`).
- Draft new `AppRoutes` behind flag; keep old routes until cutover (or branch strategy).
- Establish error mapping layer for new codes.
- Decide document upload package set; spike signed PUT upload.

**Exit criteria:** Compiling skeleton + session spike merged; flags in place.

### Phase 3: Core Implementation

Suggested order (aligned with backend §24, adjusted for Flutter value):

1. Auth/session/actor routing (blocks everything)
2. Tenant members (replace employee staff admin)
3. Contractors + engagements + profile docs
4. Clients (+ sites/contacts/invites create)
5. Form templates (minimal) + job catalog wiring
6. Jobs + visits + tasks + recurrence generate
7. Visit check-in/complete (retire kiosk)
8. Contractor timetable/availability/leave
9. Engagement rates + payment batches
10. Admin visits board / schedule redesign
11. Corrections/reporting (when APIs ready)
12. Remove obsolete employee/PIN/payroll-period code
13. Notifications event handling polish

### Phase 4: Data and Cache Migration

- Migration code: clear `payroll_settings`, old `user_role`, tokens on version bump.
- No offline DB migration (app has no SQLite workforce cache).
- Session: force re-auth; show “App updated — please sign in again”.
- Feature flag kill-switch to old app binary only via store rollback (no dual API mode per spec).

### Phase 5: Testing and QA

- Unit: models, repositories, status transition guards, permission helpers.
- Widget: login gates, visit detail, batch create, engagement actions.
- Integration: happy path invite→active; check-in enforce geofence; complete with forms; payment post.
- Regression: branch select, token refresh, first-login (if kept), push registration, responsive shell.
- Manual QA checklist: see backlog doc.

### Phase 6: Rollout

- Staging tenant seed with engagements/jobs/visits.
- Internal dogfood: one admin + one contractor device.
- Production: store release; monitor auth failures, check-in error rates, batch post failures.
- Rollback: previous store build (API must remain compatible with rollback binary **or** coordinate backend flag — **Needs Clarification** given “no back-compat”).
- Prefer **backend + app coordinated cutover window** because dual-running is out of scope.

---

## 10. Risk Assessment

| Risk | Description | Impact | Probability | Mitigation |
|---|---|---|---|---|
| Coordinated cutover failure | Spec forbids back-compat; old app breaks when API switches | Critical | High | Joint release train; force-update / store block old builds; clear messaging |
| Scope underestimation | New modules (clients, forms, docs, jobs) dwarf old employee CRUD | Critical | High | Phased delivery; cut V1 mobile scope with product |
| Dual-actor UX complexity | One binary serving admin + contractor poorly | High | High | Explicit IA; separate shells; usability testing |
| OpenAPI drift | Implementing against prose spec then mismatching backend | High | High | Contract-first; freeze OpenAPI; consumer-driven tests |
| Forms engine cost | Dynamic forms + file fields + scan gates | High | Medium | Start with limited field types; defer rich builder to web |
| Document upload on mobile | Signed GCS PUT, backgrounding, MIME limits | High | Medium | Early spike; reuse one `DocumentService` |
| Geofence UX | Enforce rejects vs informational warnings | High | Medium | Clear error copy for `geofence_rejected`; show distance if API provides |
| Engagement status edge cases | Suspended check-out allowed; ended read-only docs | High | Medium | Encode status matrix in domain helpers + tests |
| Scheduling rewrite | Team may try to “patch” employee board | High | Medium | Treat visits as source of truth; avoid hybrid board |
| Report/adjustment gap | Admin ops rely on corrections/report; APIs unclear | High | High | Block admin “ops complete” claim until APIs confirmed |
| Permission sprawl | Missing gates cause 403 UX dead-ends | Medium | High | Central permission map; empty states with reason |
| Test debt | Current tests skew payments; core flows untested | Medium | High | Require tests for visit + engagement P0 paths |
| Package / platform file pickers | iOS/Android/Web differences | Medium | Medium | Abstract file picker; test all targets early |
| Push/event noise | Stub channels + new events without client handlers | Low–Medium | Medium | Ignore unknown events safely; add handlers incrementally |

---

## 11. Backend/Product Clarification Questions

See full grouped list: [clarification-questions.md](./clarification-questions.md).

**Top blockers:**

1. Exact login response + JWT claims for `actor_type`, engagements, permissions?
2. Single Flutter app for both actors, or separate apps/flavors?
3. Which admin features are mobile V1 vs web-only (form builder, client CRM, billing)?
4. Replacement APIs for attendance exceptions, adjustments, weekly report?
5. Final paths/payloads for payment batches and engagement rates?
6. Cutover plan: force-update mechanism when old API is deleted?
7. Deep link for engagement invite accept on mobile?
8. Does Flutter web need public client-invite acknowledge screens?

---

## 12. Recommended Flutter Implementation Strategy

### Clean architecture boundaries

Keep current layers; tighten them:

```text
Presentation (views/controllers)
  → Domain (optional entities/enums/status machines) 
  → Data (repositories → datasources → DTO JSON)
```

Do not put Dio JSON parsing in controllers. Do not call `AttendanceApiClient` from controllers.

### Model / DTO separation

- `*Dto` / `fromJson` at datasource boundary.
- Immutable domain models / enums for status machines (engagement, visit).
- UI models only when display needs derived fields.

### Repository changes

- One repository per bounded context (engagements, visits, …).
- Repositories own mapping + branch/tenant header/query injection.
- Return `Result`/`Either`-style or typed exceptions mapped from §19 codes.

### State management

- Stay on GetX.
- Add `SessionController` (permanent) for auth context.
- Feature controllers scoped via bindings; dispose on shell section change where possible.

### Routing strategy

- Actor-based root graphs: `AdminRoutes` vs `ContractorRoutes`.
- Middleware: `AuthGuard` + `ActorGuard` + optional `PermissionGuard`.
- Avoid encoding actor in client-only gateway enum long-term.

### Error handling

- Central mapper: Dio error → `AppFailure(code, message)`.
- Special-case: `geofence_rejected`, `forms_incomplete`, `engagement_inactive`, `visit_overlap`.
- Snackbars/dialogs standardized.

### Backward compatibility

- **Do not** build dual clocking modes.
- Version gate: if API returns identity error / unexpected shape, force logout + update prompt.
- Coordinate with backend deprecation date.

### Feature flagging

- Compile-time: `--dart-define=DOMAIN_V2=true` for early builds.
- Optional remote config later for section-level toggles (clients, payments).
- Flags must not expect old APIs once backend cut over.

### API versioning

- Continue `/v1` prefix as spec.
- Isolate path constants; if backend introduces `/v2`, only constants + DTOs change.

### Testing approach

- `mocktail` datasources for controller tests.
- Golden/widget for critical visit UI.
- Contract tests once OpenAPI available (optional `openapi_generator` — team decision).

---

## 13. Estimated Effort and Priority

| Workstream | Estimate | Priority | Notes |
|------------|----------|----------|-------|
| Discovery / contract freeze | Small–Medium | P0 | Blocks coding quality |
| Auth/session/switch-tenant/actor routing | Large | P0 | Foundation |
| Remove PIN kiosk + employee clock | Medium | P0 | Delete + replace entry points |
| Tenant members module | Medium | P0 | Admin staff |
| Contractors + engagements + docs (profile) | Extra Large | P0 | Core relationship |
| Clients/sites/contacts/invites | Large | P1 | Needed for standing jobs |
| Forms (consume + submit; builder may be P2) | Large | P1 | Blocks visit complete |
| Jobs/visits/tasks/recurrence | Extra Large | P0 | Core work model |
| Visit check-in/complete GPS | Large | P0 | Contractor core loop |
| Scheduling/timetable retarget | Large | P1 | Admin + contractor |
| Engagement rates | Medium | P1 | |
| Payment batches | Large | P1 | Replaces payroll periods |
| Remove payroll period stack | Medium | P0 | Once batches land |
| Attendance corrections/reports redesign | Large | P1 | Pending API |
| Notifications polish | Small–Medium | P2 | |
| Billing UI | Small / Unknown | P3 | Likely out of mobile V1 |
| Test hardening + QA | Large | P0 | Parallel from Phase 3 |
| **Overall program** | **Extra Large** | **P0** | Multi-sprint platform migration |

**Rough sequencing priority:** P0 auth → P0 engagements/jobs/visits/check-in → P1 clients/forms/payments/schedule → P2 polish → P3 billing.

---

## 14. Suggested Task Breakdown

See executable backlog: [development-backlog.md](./development-backlog.md).

---

## 15. Final Recommendations

1. **Treat this as a platform migration**, not a feature epic. Budget Extra Large effort and a coordinated API/app cutover.
2. **Freeze OpenAPI + UX scope** before rewriting UI (Phase 1). The design doc is backend-normative and explicitly out-of-scopes frontend UX.
3. **Build two shells** (tenant member admin vs contractor) on one codebase with a shared session layer.
4. **Delete, don’t dual-run:** PIN kiosk, free-floating clock, payroll periods — per spec §23.
5. **Make visits the atomic unit** of time, forms, docs, and payment in the Flutter mental model.
6. **Invest early** in session/RBAC, documents upload, and dynamic forms — these unblock the most features.
7. **Keep GetX + layered repos** to reduce migration risk; fix layering leaks (no Dio in controllers).
8. **Force re-login** on cutover; clear payroll settings and portal role keys.
9. **Do not start large UI builds** for reports/adjustments/billing until APIs are confirmed.
10. Use the companion docs in this folder as the working engineering checklist; update them when backend answers land.

---

*End of impact study. Companion files: mapping-table.md, clarification-questions.md, development-backlog.md.*
