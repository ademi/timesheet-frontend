# Employee Shift Schedule — Implementation Plan

Implementation plan for the **Employee Shift Schedule** admin screen in the Flutter app.

**Source spec:** [flutter-employee-shift-schedule-screen-guide.md](./flutter-employee-shift-schedule-screen-guide.md)  
**Architecture:** GetX + layered data (controller → repository → remote datasource → models)  
**UI reference:** `AttendanceReportView`, `AdminHubCard`, `AdminShellRoutes`

---

## Architecture alignment

| Doc recommendation | This codebase |
|--------------------|---------------|
| Riverpod / `AsyncValue` | **GetX** — `.obs`, `Obx`, `GetView<Controller>`, `Bindings` |
| Repository pattern | Same — mirror `PayrollRepository` + `PayrollModuleBinding` |
| Branch from `GET /v1/branches` | Reuse existing `BranchRepository` / `BranchModel` |
| Week grid | Mirror `AttendanceReportView` (`data_table_2`, card container, date controls) |
| Admin entry | New `AdminHubCard` + `AdminPanelController.openShiftSchedule()` |
| Wide layout rail | Extend `AdminShellRoutes` (6th destination) |
| Permissions | **Not implemented yet** — JWT decode or `GET /v1/me` required |

---

## Delivery phases

| Phase | Scope | Outcome |
|-------|--------|---------|
| **MVP** | Phases 0–7 | View Today + Week grid, summary chips, read-only cell sheet, pull-to-refresh |
| **Manage** | Phase 8 | Edit actions gated by `scheduling.manage` |
| **Advanced** | Phase 9–11 | Template CRUD, bulk assign, polish, testing |

---

## Phase 0 — Discovery & scope lock

- [x] Confirm MVP vs full feature scope with team (MVP = view-only first recommended)
- [x] Verify backend is reachable — smoke-test `GET /v1/scheduling/board/today` with demo admin
- [x] Confirm branch context — default to `TokenStorage.branchId`; decide if screen allows branch override
- [x] Decide permissions approach — JWT decode vs `GET /v1/me`
- [x] Decide shell rail — add 6th “Schedule” item vs hub-card-only entry

### Phase 0 — Locked decisions (2026-06-27)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Phasing** | MVP first (Phases 0–7 view-only), then Phase 8 manage flows | Matches plan delivery table; reduces risk; backend guide supports incremental rollout |
| **Backend smoke test** | Deferred — `http://11.0.0.98:8000` timed out from dev machine (no running backend / network). Re-test manually after login with bearer token | Unauthenticated probe not sufficient; integration verified during Phase 11 |
| **Branch context** | Default to `TokenStorage.branchId`; **allow branch override** via AppBar dropdown using existing `BranchRepository` | Doc requires branch picker; admin may manage multiple branches without re-selecting at gateway |
| **Permissions** | **JWT decode** via `dart_jsonwebtoken` in `TokenStorage` (extend existing `needsProactiveRefresh` pattern) | No `/v1/me` in codebase today; avoids extra API call; token already stored |
| **Shell rail** | **Add 6th “Schedule” destination** in `AdminShellRoutes` | Consistent with Attendance Report / Corrections as first-class admin sections |

---

## Phase 1 — Data layer foundation

### 1.1 Models (`lib/app/data/models/scheduling/`)

- [x] Create `shift_status.dart` — `assigned`, `onLeave`, `unassigned`, `dayOff`
- [x] Create `shift_source.dart` — `recurring`, `override`, `leave`
- [x] Create `schedule_template.dart` — id, name, shift times, color, sort order, etc.
- [x] Create `board_day.dart` — date, status, source, template fields, conflicts, `clocked_in`, `is_late`
- [x] Create `board_employee.dart` — employeeId, fullName, employeeCode, days[]
- [x] Create `board_meta.dart` — assigned/unassigned/onLeave/dayOff/conflict counts
- [x] Create `schedule_board.dart` — branchId, start/end, templates[], employees[], meta
- [x] Create request/response DTOs — `AssignmentUpsertRequest`, `LeaveCreateRequest`, `CopyWeekRequest`, `EmployeeScheduleCreateRequest`, etc.
- [x] Use snake_case in `fromJson`; camelCase in Dart fields (match `BranchModel` convention)

### 1.2 API constants

- [x] Add scheduling path constants to `lib/core/constants/app_constants.dart`

### 1.3 Remote datasource

- [x] Create `lib/app/data/datasources/remote/scheduling_remote_datasource.dart`
- [x] Use `AttendanceApiClient().dio` (same as payroll/employee)
- [x] Implement `GET /v1/scheduling/board/today?branch_id=&status=`
- [x] Implement `GET /v1/scheduling/board?branch_id=&start=&end=&status=`
- [x] Implement `GET /v1/scheduling/templates`
- [x] Implement `PUT /v1/scheduling/assignments`
- [x] Implement `GET /v1/scheduling/assignments?start=&end=&branch_id=`
- [x] Implement `DELETE /v1/scheduling/assignments/{id}`
- [x] Implement `POST /v1/scheduling/leave`
- [x] Implement `DELETE /v1/scheduling/leave/{id}`
- [x] Implement `POST /v1/scheduling/employee-schedules`
- [x] Implement `GET /v1/scheduling/employee-schedules?employee_id=`
- [x] Implement `PATCH /v1/scheduling/employee-schedules/{id}`
- [x] Implement `DELETE /v1/scheduling/employee-schedules/{id}`
- [x] Implement `POST /v1/scheduling/assignments/bulk`
- [x] Implement `POST /v1/scheduling/copy-week`
- [x] Implement `POST /v1/scheduling/templates` (advanced)
- [x] Implement `PATCH /v1/scheduling/templates/{id}` (advanced)

### 1.4 Repository

- [x] Create `lib/app/data/repositories/scheduling_repository.dart`
- [x] Inject `SchedulingRemoteDataSource` + `TokenStorage`
- [x] Default `branchId` from `_tokenStorage.branchId`
- [x] Support optional `branchId` override for branch picker
- [x] Add date formatting helper — `yyyy-MM-dd` for query params
- [x] Map `DioException` status codes (401/403/409/422) for controller handling

### 1.5 Module binding

- [x] Create `lib/app/bindings/scheduling_module_binding.dart`
- [x] Register chain: `TokenStorage` → `ApiClient` → `AttendanceApiClient` → `SchedulingRemoteDataSource` → `SchedulingRepository`
- [x] Reuse or register `BranchRepository` if needed

---

## Phase 2 — Permissions

**Requires:** `scheduling.read` (view), `scheduling.manage` (edit)

- [x] Add permission reader — extend `TokenStorage` with JWT decode **or** add `GET /v1/me` to auth datasource
- [x] Expose `canViewSchedule` and `canManageSchedule` in controller as `.obs` bools
- [x] Hide FAB and edit sheet actions when `!canManageSchedule`
- [x] Show read-only cell detail when user has only `scheduling.read`
- [x] Handle 403 on board fetch — show “No access” empty state with back button

### Phase 2 — Implementation notes (2026-06-27)

| Item | Location |
|------|----------|
| Permission constants | `lib/app/constants/scheduling_permissions.dart` |
| JWT `permissions` claim | `TokenStorage.permissions`, `hasPermission`, `canViewSchedule`, `canManageSchedule` |
| Controller state | `lib/app/controllers/shift_schedule_controller.dart` |
| Binding | `lib/app/bindings/shift_schedule_binding.dart` |
| No-access UI | `lib/app/views/widgets/shift_schedule_no_access.dart` |
| Read-only / gated cell sheet | `lib/app/views/widgets/shift_schedule_cell_sheet.dart` |
| Gated FAB | `lib/app/views/widgets/shift_schedule_fab.dart` |
| Unit tests | `test/core/services/token_storage_test.dart` |

---

## Phase 3 — Routing & admin integration

- [x] Add `AppRoutes.adminShiftSchedule = '/admin/shift-schedule'` in `app_routes.dart`
- [x] Register `GetPage` in `app_pages.dart` — `AuthGuard`, `adminShellPage(ShiftScheduleView())`, `ShiftScheduleBinding()`
- [x] Add `AdminHubCard` in `admin_panel_view.dart` — icon `Icons.calendar_view_week_rounded`, title **Shift Schedule**
- [x] Add `openShiftSchedule()` in `admin_panel_controller.dart` — `SchedulingModuleBinding.ensureDependencies()` + `Get.toNamed(...)`
- [x] Extend `admin_shell_routes.dart` — 6th rail item “Schedule”, `_shiftScheduleRoutes` set
- [x] Update `selectedIndex`, `navigateTo`, `isShellRoute` in `admin_shell_routes.dart`
- [x] Create `lib/app/bindings/shift_schedule_binding.dart` — `ensureDependencies()` + `Get.lazyPut<ShiftScheduleController>`

### Phase 3 — Implementation notes (2026-06-27)

| Item | Location |
|------|----------|
| Route constant | `AppRoutes.adminShiftSchedule` |
| GetPage registration | `app_pages.dart` (after corrections) |
| Admin hub card | `admin_panel_view.dart` (after Corrections) |
| Shell rail index | 3 — Schedule (Payroll → 4, Payments → 5) |
| Minimal screen shell | `lib/app/views/shift_schedule_view.dart` |

---

## Phase 4 — Controller & screen shell

### 4.1 Controller (`shift_schedule_controller.dart`)

- [x] Create `ShiftScheduleController` extending `GetxController`
- [x] Add reactive state: `selectedBranchId`, `weekStart`, `isTodayView`, `statusFilter`, `board`, `isLoading`, `canManage`, `branches`
- [x] `onInit` — load permissions, branches, default branch from `TokenStorage`, fetch today board
- [x] Debounce week navigation (~300ms) before API call
- [x] Implement `refreshBoard()` — re-fetch after writes
- [x] Implement `goToPreviousWeek()` / `goToNextWeek()` / `goToToday()`
- [x] Implement `toggleView(Today | Week)`
- [x] Implement `selectBranch(id)` — persist via `TokenStorage.persistBranchSelection`, refresh board
- [x] Implement `applyStatusFilter(ShiftStatus?)` — refetch with filter
- [x] Implement `openCellDetail(BoardEmployee, BoardDay)` — open bottom sheet

### 4.2 View shell (`shift_schedule_view.dart`)

- [x] Create `ShiftScheduleView extends GetView<ShiftScheduleController>`
- [x] AppBar — `AppBackButton(fallbackRoute: AppRoutes.adminPanel)`, title “Shift Schedule”, `AppColors.darkBrown`
- [x] Branch dropdown in AppBar actions
- [x] Date nav row — prev / week range label / next + **Today** shortcut
- [x] View toggle — segmented control **Today** | **Week**
- [x] Summary chips row from `board.meta`
- [x] Body — `MaxWidthBox(maxWidth: Breakpoints.maxContent)` + pull-to-refresh
- [x] Loading / empty states — match `AttendanceReportView` patterns
- [x] FAB — visible only when `canManage`

### Phase 4 — Implementation notes (2026-06-27)

| Widget | Location |
|--------|----------|
| Week navigator | `shift_schedule_week_navigator.dart` |
| Today / Week toggle | `ShiftScheduleViewToggle` in `shift_schedule_summary_chips.dart` |
| Summary filter chips | `shift_schedule_summary_chips.dart` |
| Date formatting | `shift_schedule_utils.dart` |
| Conflict-only filter | `conflictFilterOnly` on controller (client-side, Phase 6 grid) |

---

## Phase 5 — Today view (Flow A)

- [x] Fetch `GET /scheduling/board/today?branch_id=` on screen load
- [x] Render vertical list — employee name + code, shift name + time range
- [x] Add status badges — On leave, Unassigned, Clocked in (green), Late (orange/red), Conflict (red)
- [x] Support status filter via query param when summary chip tapped
- [x] Tap row → open cell bottom sheet

### Phase 5 — Implementation notes (2026-06-27)

| Widget | Location |
|--------|----------|
| Today list | `shift_schedule_today_list.dart` |
| Status badges | `shift_schedule_status_badges.dart` |
| Today day resolver | `todayDayFor()`, `todayEmployees` on controller |
| Template avatar color | `colorForTemplate()` |

---

## Phase 6 — Week grid view (Flow B)

- [x] Compute `start` = Monday, `end` = start + 6 days
- [x] Fetch `GET /scheduling/board?branch_id=&start=&end=` when switching to Week or changing week
- [x] Build scrollable grid — `DataTable2` or custom sticky employee column
- [x] Rows = employees, columns = dates in range (7 days)
- [x] Cell widget from `employee.days[i]`
- [x] Horizontal + vertical scroll on phone; full grid on tablet/desktop

### Phase 6 — Implementation notes (2026-06-27)

| Widget | Location |
|--------|----------|
| Week grid | `shift_schedule_week_grid.dart` (`DataTable2`, `fixedLeftColumns: 1`) |
| Schedule cell | `shift_schedule_cell.dart` (includes Phase 7 styling) |
| Week helpers | `weekEmployees`, `weekDates`, `dayForEmployee`, `isTodayDate` on controller |

---

## Phase 7 — Cell widgets & visual design

- [x] Create `lib/app/views/widgets/shift_schedule_cell.dart`
- [x] **assigned** — background = `template.color` (fallback `AppColors.primary` container)
- [x] **on_leave** — grey fill / diagonal stripes
- [x] **unassigned** — dashed border, light warning tint
- [x] **day_off** — neutral outline, “Off” label
- [x] **override** source — small dot/icon overlay
- [x] **conflicts** — red corner badge; tooltip from conflict code map
- [x] **Today + assigned** — green dot if `clocked_in`, orange if `is_late`, hollow if not clocked in

| Conflict code | User-facing message |
|---------------|---------------------|
| `overlapping_recurring` | Multiple recurring schedules overlap |
| `leave_vs_assignment` | Employee on leave but also assigned a shift |

---

## Phase 8 — Cell bottom sheet & edit flows

### 8.1 Read-only sheet (all users with `scheduling.read`)

- [x] Create `shift_schedule_cell_sheet.dart`
- [x] Show employee name, date, resolved status, source, shift times, conflict messages

### 8.2 Manage actions (`scheduling.manage` only)

- [x] **Change shift (override)** — `PUT /assignments` + template picker from `board.templates`
- [x] **Mark day off** — `PUT /assignments` (template null, `is_day_off: true`) + confirm dialog
- [x] **Mark leave (range)** — `POST /scheduling/leave` + date range + leave type dropdown
- [x] **Clear override** — `GET assignments` → `DELETE` + confirm dialog
- [x] **View/edit recurring** — `GET/POST/PATCH/DELETE employee-schedules` + sub-sheet or form
- [x] **Copy last week** — `POST /copy-week` (`mode: overrides_only`) + confirm dialog from AppBar/FAB menu
- [ ] **Bulk assign** — `POST /assignments/bulk` + multi-select mode on grid (deferred — advanced)
- [x] After every successful write — `refreshBoard()` + success snackbar
- [x] Handle **409 Conflict** — dialog with backend message (overlapping recurring)

### Phase 8 — Implementation notes (2026-06-27)

| Item | Location |
|------|----------|
| Write actions | `ShiftScheduleController` (`_runWrite`, `_handleWriteError`) |
| Dialogs / pickers | `shift_schedule_manage_dialogs.dart` |
| Cell actions UI | `shift_schedule_cell_sheet.dart` |
| FAB menu (copy week) | `ShiftScheduleFab` → `openFabMenu()` |
| 422 errors | `_extractErrorMessage` parses validation list |

---

## Phase 9 — Extract widgets & helpers

- [x] Create `shift_schedule_summary_chips.dart` — meta filter chips
- [x] Create `shift_schedule_week_navigator.dart` — prev/next week + label
- [x] Create `shift_schedule_today_list.dart` — Today view body
- [x] Create `shift_schedule_week_grid.dart` — Week grid body
- [x] Create `shift_schedule_utils.dart` — week start calculation, `#RRGGBB` color parsing, time formatting
- [x] Keep `shift_schedule_view.dart` thin; logic in controller

### Phase 9 — Additional extractions (2026-06-27)

| Widget | Location |
|--------|----------|
| Top controls card | `shift_schedule_top_controls.dart` |
| Main body layout | `shift_schedule_body.dart` |
| Thin screen shell | `shift_schedule_view.dart` (~70 lines) |

---

## Phase 10 — Error handling & polish

- [x] **401** — rely on existing auth interceptor → login redirect
- [x] **403** — read-only or “No access” state
- [x] **404** — snackbar + refresh branches
- [x] **409** — conflict dialog
- [x] **422** — show field errors from response body
- [x] **Network errors** — generic snackbar + retry
- [x] Pull-to-refresh on Today and Week views
- [x] Debounce rapid week arrow taps (300ms)
- [x] Cache `templates` in controller for pickers; invalidate on template CRUD

---

## Phase 11 — Testing

### Manual smoke test

See [shift-schedule-manual-smoke-test.md](./shift-schedule-manual-smoke-test.md) — run when backend is available.

- [ ] Login as demo admin
- [ ] Open admin panel → tap **Shift Schedule** card
- [ ] Verify Today view loads with mixed employee statuses
- [ ] Switch to Week view — grid renders 7 columns
- [ ] Tap cell — bottom sheet shows correct status and times
- [ ] Change one cell assignment — refresh shows update
- [ ] Copy last week — verify new overrides appear
- [ ] Verify **DEMO-E04** shows unassigned
- [ ] Verify **Employee1** shows daily override on 2026-06-23
- [ ] Verify **Employee2** shows leave 2026-06-24 to 2026-06-25

### Widget tests (optional)

- [x] Cell renders correct color for each `ShiftStatus`
- [x] Conflict badge visible when `conflicts.isNotEmpty`
- [ ] Edit actions hidden when `canManage == false` (covered by permission gating in sheet)
- [x] Week navigation updates `start`/`end` query params

**Automated:** `test/app/views/widgets/shift_schedule_cell_test.dart` (5 tests passing)

---

## New files checklist

```
lib/app/
├── bindings/
│   ├── scheduling_module_binding.dart      ← NEW
│   └── shift_schedule_binding.dart         ← NEW
├── controllers/
│   └── shift_schedule_controller.dart      ← NEW
├── data/
│   ├── datasources/remote/
│   │   └── scheduling_remote_datasource.dart
│   ├── models/scheduling/                  ← NEW folder
│   └── repositories/
│       └── scheduling_repository.dart
├── views/
│   ├── shift_schedule_view.dart            ← NEW
│   └── widgets/
│       ├── shift_schedule_cell.dart
│       ├── shift_schedule_week_grid.dart
│       ├── shift_schedule_today_list.dart
│       ├── shift_schedule_summary_chips.dart
│       └── shift_schedule_cell_sheet.dart
└── routes/
    ├── app_routes.dart                     ← EDIT
    └── app_pages.dart                      ← EDIT
```

---

## Implementation order

```
Phase 1 (Data layer)
    ↓
Phase 2 (Permissions)
    ↓
Phase 3 (Routes + AdminHubCard + Shell rail)
    ↓
Phase 4 (Controller + View shell)
    ↓
Phase 5 (Today view)
    ↓
Phase 6–7 (Week grid + cell styling)
    ↓
Phase 8 (Bottom sheet — read-only, then manage flows)
    ↓
Phase 9–10 (Extract widgets + polish)
    ↓
Phase 11 (Manual smoke test)
```

---

## Key reference files

| Purpose | Path |
|---------|------|
| Backend spec | `docs/flutter-employee-shift-schedule-screen-guide.md` |
| Admin home | `lib/app/views/admin_panel_view.dart` |
| Admin controller | `lib/app/controllers/admin_panel_controller.dart` |
| Hub card widget | `lib/app/widgets/admin_hub_card.dart` |
| Route table | `lib/app/routes/app_pages.dart` |
| Shell rail | `lib/app/views/shell/admin_shell_routes.dart` |
| Module binding template | `lib/app/bindings/payroll_module_binding.dart` |
| Repository template | `lib/app/data/repositories/employee_repository.dart` |
| Grid report (similar UI) | `lib/app/views/attendance_report_view.dart` |
| API base URL | `lib/core/constants/app_constants.dart` |
| Branch model/repo | `lib/app/data/models/branch/branch_model.dart` |

---

## Open decisions

- [x] **Phasing** — Read-only MVP first (Phases 0–7), then manage flows (Phase 8)
- [x] **Branch picker** — Default `TokenStorage.branchId` with optional override dropdown on screen
- [x] **Permissions** — JWT decode in `TokenStorage` (`permissions` claim array)
- [x] **Shell rail** — Add “Schedule” as 6th permanent rail item
