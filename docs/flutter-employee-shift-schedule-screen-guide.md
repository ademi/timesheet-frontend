# Flutter Guide: Employee Shift Schedule Screen

Use this document when implementing the **Employee Shift Schedule** admin screen in the Flutter app, or when prompting an AI assistant to build it. It describes the UI goals, API contracts, data models, user flows, and recommended architecture.

**Backend reference:** [employee-shift-schedule-backend-implementation.md](./employee-shift-schedule-backend-implementation.md)  
**RBAC:** User needs `scheduling.read` (view) and `scheduling.manage` (edit actions)

---

## 1. Screen purpose (product brief)

Build a **lite HR schedule board** that lets admins quickly see and manage who works when.

### Questions the screen must answer

| Question | UI element | Primary API |
|----------|------------|-------------|
| Who is working today? | Today tab / default view | `GET /v1/scheduling/board/today` |
| What shift is each employee on? | Week grid cells with template name + times | `GET /v1/scheduling/board` |
| Any gaps or conflicts? | Red badge, conflict filter, summary chip | `meta.conflict_count`, `days[].conflicts` |
| Who is on leave? | Grey/striped cells, leave chip | `status == on_leave` |
| Who is unassigned? | Empty cells, unassigned filter/section | `status == unassigned` |
| Copy/repeat shifts? | "Copy last week" action | `POST /v1/scheduling/copy-week` |

Keep the UI **simple, visual, and fast**. Prefer one main board API call over many small requests.

---

## 2. Prerequisites

### Authentication

All requests require:

```
Authorization: Bearer <access_token>
```

Obtain token from existing login flow: `POST /v1/auth/login`

Verify permissions from JWT or `GET /v1/me`:

```json
{
  "permissions": ["scheduling.read", "scheduling.manage", ...]
}
```

- Show screen in **read-only mode** if user has only `scheduling.read`
- Hide edit FAB / actions without `scheduling.manage`

### Base URL

Use your app's configured API base, e.g. `https://api.example.com/v1`

OpenAPI docs (when backend running): `{base}/docs` → tag **scheduling**

---

## 3. Recommended screen layout

```
┌─────────────────────────────────────────────────────────┐
│  ← Shift Schedule                    [Branch ▼]         │
├─────────────────────────────────────────────────────────┤
│  ◀  Mon 23 Jun – Sun 29 Jun  ▶        [Today] [Week]   │
├─────────────────────────────────────────────────────────┤
│  Assigned 12 │ Unassigned 2 │ Leave 1 │ Conflicts 0   │  ← summary chips
├─────────────────────────────────────────────────────────┤
│         Mon   Tue   Wed   Thu   Fri   Sat   Sun         │
│  Jane   [Day] [Day] [---] [Day] [Day] [off] [---]       │
│  Bob    [Early][Lv] [Lv]  [Day] [Day] [---] [---]       │
│  ...                                                     │
├─────────────────────────────────────────────────────────┤
│                              [+] Assign / actions        │
└─────────────────────────────────────────────────────────┘
```

### Sections

1. **App bar** — title + branch dropdown
2. **Date navigation** — week range picker, prev/next week, "Today" shortcut
3. **View toggle** — Today list vs Week grid
4. **Summary chips** — tap to filter (optional)
5. **Main content** — grid or list
6. **FAB / menu** — assign shift, mark leave, copy week (manage permission only)

### Cell tap → bottom sheet

When user taps a day cell:

- Show resolved status, source (`recurring` / `override` / `leave`), shift times
- Actions (if `scheduling.manage`):
  - Change shift (daily override)
  - Mark day off
  - Mark leave (date range)
  - Clear override (revert to recurring)
  - View/edit recurring rule

---

## 4. API integration map

### On screen load (minimum)

| Step | Endpoint | Notes |
|------|----------|-------|
| 1 | `GET /v1/branches` | Populate branch picker; persist last selected branch |
| 2 | `GET /v1/scheduling/board/today?branch_id={id}` | Fast first paint for Today view |
| 3 | `GET /v1/scheduling/board?branch_id={id}&start={mon}&end={sun}` | Week grid when user switches to Week |

**Tip:** For week view, compute `start` = Monday (or your locale week start) and `end` = start + 6 days.

Optional parallel call for header chips only:

```
GET /v1/scheduling/summary?branch_id={id}&date={today}
```

Board response already includes `meta` counts — summary is optional if you use `board.meta`.

### Shift legend

Templates with colors come inside the board response (`templates[]`). You can also call:

```
GET /v1/scheduling/templates
```

Use `template.color` for cell background and legend swatches.

---

## 5. Dart models (suggested)

Create models matching the API JSON. Example structure (adjust naming to your project conventions):

```dart
enum ShiftStatus { assigned, onLeave, unassigned, dayOff }

enum ShiftSource { recurring, override, leave }

class ScheduleTemplate {
  final String id;
  final String name;
  final String shiftStart; // "09:00:00"
  final String shiftEnd;
  final int breakMinutesDefault;
  final bool isActive;
  final String? branchId;
  final String? color; // "#4CAF50"
  final int sortOrder;

  factory ScheduleTemplate.fromJson(Map<String, dynamic> j) => ScheduleTemplate(
    id: j['id'],
    name: j['name'],
    shiftStart: j['shift_start'],
    shiftEnd: j['shift_end'],
    breakMinutesDefault: j['break_minutes_default'],
    isActive: j['is_active'],
    branchId: j['branch_id'],
    color: j['color'],
    sortOrder: j['sort_order'] ?? 0,
  );
}

class BoardDay {
  final DateTime date;
  final ShiftStatus status;
  final ShiftSource? source;
  final String? templateId;
  final String? templateName;
  final String? shiftStart;
  final String? shiftEnd;
  final List<String> conflicts;
  final bool isWorkingToday;
  final bool? clockedIn;
  final bool? isLate;

  factory BoardDay.fromJson(Map<String, dynamic> j) {
    return BoardDay(
      date: DateTime.parse(j['date']),
      status: _parseStatus(j['status']),
      source: j['source'] != null ? _parseSource(j['source']) : null,
      templateId: j['template_id'],
      templateName: j['template_name'],
      shiftStart: j['shift_start'],
      shiftEnd: j['shift_end'],
      conflicts: List<String>.from(j['conflicts'] ?? []),
      isWorkingToday: j['is_working_today'] ?? false,
      clockedIn: j['clocked_in'],
      isLate: j['is_late'],
    );
  }
}

class BoardEmployee {
  final String employeeId;
  final String fullName;
  final String employeeCode;
  final String? branchId;
  final bool isActive;
  final List<BoardDay> days;
  // fromJson...
}

class ScheduleBoard {
  final String branchId;
  final DateTime startDate;
  final DateTime endDate;
  final List<ScheduleTemplate> templates;
  final List<BoardEmployee> employees;
  final BoardMeta meta;
  // fromJson...
}

class BoardMeta {
  final int assignedCount;
  final int unassignedCount;
  final int onLeaveCount;
  final int dayOffCount;
  final int conflictCount;
  // fromJson...
}
```

Parse API snake_case in `fromJson`; use camelCase in Dart classes.

---

## 6. Visual design rules

### Cell colors by status

| Status | Suggested treatment |
|--------|---------------------|
| `assigned` | Background = `template.color` (fallback: theme primaryContainer) |
| `on_leave` | Grey diagonal stripes or muted grey fill |
| `unassigned` | Empty / dashed border / light warning tint |
| `day_off` | Neutral outline, label "Off" |

### Source indicator

Show a small dot or icon when `source == override` so admins know the day differs from recurring rule.

### Conflict indicator

If `conflicts.isNotEmpty`, show red corner badge. Tooltip text:

| Code | User-facing message |
|------|---------------------|
| `overlapping_recurring` | Multiple recurring schedules overlap |
| `leave_vs_assignment` | Employee on leave but also assigned a shift |

### Today extras

When cell date is today and `status == assigned`:

- Green dot if `clocked_in == true`
- Orange/red if `is_late == true`
- Hollow dot if not clocked in yet

---

## 7. User flows and API calls

### Flow A: View today's roster

```
GET /v1/scheduling/board/today?branch_id={branchId}
```

Render as vertical list:

- Employee name + code
- Shift name + time range
- Badges: On leave, Unassigned, Clocked in, Late, Conflict

Optional filter:

```
GET /v1/scheduling/board/today?branch_id={id}&status=unassigned
```

Valid `status` values: `assigned`, `on_leave`, `unassigned`, `day_off`

### Flow B: View week grid

```
GET /v1/scheduling/board?branch_id={id}&start=2026-06-23&end=2026-06-29
```

Build a `DataTable` or custom scrollable grid:

- Rows = `employees`
- Columns = dates in range (usually 7)
- Cell widget from `employee.days[i]`

### Flow C: Assign recurring shift (default pattern)

Use when employee should work the same shift every day for a period.

```
POST /v1/scheduling/employee-schedules
Content-Type: application/json

{
  "employee_id": "uuid",
  "template_id": "uuid",
  "start_date": "2026-07-01",
  "end_date": null
}
```

Response: `{ "id": "uuid" }`

On **409 Conflict** — show message that overlapping recurring schedule exists; offer to edit existing.

List existing recurring rules:

```
GET /v1/scheduling/employee-schedules?employee_id={id}
```

Update / delete:

```
PATCH /v1/scheduling/employee-schedules/{scheduleId}
DELETE /v1/scheduling/employee-schedules/{scheduleId}
```

### Flow D: One-day override (change shift for single day)

```
PUT /v1/scheduling/assignments
{
  "employee_id": "uuid",
  "work_date": "2026-06-25",
  "template_id": "uuid",
  "is_day_off": false,
  "notes": "Covering morning shift"
}
```

Response: `{ "id": "uuid" }`

### Flow E: Mark day off (override)

```
PUT /v1/scheduling/assignments
{
  "employee_id": "uuid",
  "work_date": "2026-06-28",
  "template_id": null,
  "is_day_off": true
}
```

### Flow F: Remove override (revert to recurring)

1. List overrides to get id:
   ```
   GET /v1/scheduling/assignments?start={date}&end={date}&branch_id={id}
   ```
2. Delete:
   ```
   DELETE /v1/scheduling/assignments/{assignmentId}
   ```

### Flow G: Mark leave

```
POST /v1/scheduling/leave
{
  "employee_id": "uuid",
  "start_date": "2026-06-24",
  "end_date": "2026-06-25",
  "leave_type": "annual",
  "notes": "Vacation"
}
```

Remove leave:

```
DELETE /v1/scheduling/leave/{leaveId}
```

Leave types: `annual`, `sick`, `unpaid`, `other`

### Flow H: Bulk assign same shift to multiple cells

After multi-select in grid:

```
POST /v1/scheduling/assignments/bulk
{
  "template_id": "uuid",
  "is_day_off": false,
  "items": [
    { "employee_id": "uuid1", "work_date": "2026-06-24" },
    { "employee_id": "uuid2", "work_date": "2026-06-24" }
  ]
}
```

Response: `{ "copied_count": 2 }`

### Flow I: Copy last week to next week

```
POST /v1/scheduling/copy-week
{
  "branch_id": "uuid",
  "source_start": "2026-06-16",
  "target_start": "2026-06-23",
  "mode": "overrides_only"
}
```

| Mode | When to use |
|------|-------------|
| `overrides_only` | Safe default — copies only explicit daily overrides |
| `resolved` | Copies the full resolved week (recurring + overrides) as new daily rows |

Optional filter:

```json
"employee_ids": ["uuid1", "uuid2"]
```

Response:

```json
{ "copied_count": 14, "mode": "overrides_only" }
```

After success, refresh board.

### Flow J: Manage shift templates

List (for pickers):

```
GET /v1/scheduling/templates
```

Create:

```
POST /v1/scheduling/templates
{
  "name": "Night shift",
  "shift_start": "22:00:00",
  "shift_end": "06:00:00",
  "break_minutes_default": 30,
  "color": "#9C27B0",
  "sort_order": 3
}
```

Update:

```
PATCH /v1/scheduling/templates/{id}
{ "color": "#FF5722", "is_active": false }
```

---

## 8. State management (recommended)

### Suggested state shape

```dart
class ScheduleScreenState {
  final String? selectedBranchId;
  final DateTime weekStart;
  final bool isTodayView;
  final ShiftStatus? statusFilter;
  final AsyncValue<ScheduleBoard> board;
  final List<Branch> branches;
  final bool canManage;
}
```

### Repository pattern

```dart
abstract class SchedulingRepository {
  Future<ScheduleBoard> getBoardToday(String branchId, {ShiftStatus? status});
  Future<ScheduleBoard> getBoard(String branchId, DateTime start, DateTime end, {ShiftStatus? status});
  Future<ScheduleSummary> getSummary(String branchId, DateTime date);
  Future<List<ScheduleTemplate>> getTemplates();
  Future<void> upsertAssignment({...});
  Future<void> createLeave({...});
  Future<CopyWeekResult> copyWeek({...});
  // ...
}
```

### Refresh strategy

- Pull-to-refresh → re-fetch board
- After any write → invalidate and re-fetch board for current range
- Debounce week navigation (300ms) to avoid rapid API calls

---

## 9. Error handling

| HTTP | Meaning | UI action |
|------|---------|-----------|
| 401 | Token expired | Redirect to login |
| 403 | Missing permission | Show read-only or "No access" |
| 404 | Branch/employee/template not found | Toast + refresh branches |
| 409 | Overlapping recurring schedule | Dialog with conflict details |
| 422 | Validation error | Show field errors from response |
| 400 | Bad date range (`end` before `start`) | Fix picker |

---

## 10. AI assistant prompt template

Copy and adapt when asking an AI to implement the Flutter screen:

---

**Prompt:**

> Implement an Employee Shift Schedule admin screen in Flutter for our timesheet HR app.
>
> **Goal:** Lite HR board — who works today, shift assignments, leave, unassigned, conflicts, copy week.
>
> **Auth:** Bearer JWT; require `scheduling.read` to view, `scheduling.manage` to edit.
>
> **API base:** `{YOUR_API_BASE}/v1`
>
> **Primary data source:** `GET /scheduling/board/today?branch_id=` for Today view; `GET /scheduling/board?branch_id=&start=&end=` for week grid. Response includes `employees[].days[]` with `status`, `source`, `template_name`, `shift_start`, `shift_end`, `conflicts`, `clocked_in`, `is_late`, and `meta` counts.
>
> **Branch picker:** `GET /branches`
>
> **Edit actions (manage only):**
> - Recurring: `POST /scheduling/employee-schedules`
> - Daily override: `PUT /scheduling/assignments`
> - Leave: `POST /scheduling/leave`
> - Copy week: `POST /scheduling/copy-week` with `mode: overrides_only`
>
> **UI:** App bar + branch dropdown + week navigator + summary chips + week grid (employees × 7 days) with color-coded cells from `template.color`. Tap cell → bottom sheet with actions. Today view as list with clocked-in/late badges.
>
> **Status colors:** assigned = template color; on_leave = grey stripes; unassigned = dashed empty; day_off = "Off" label. Red badge if `conflicts` not empty.
>
> **Docs:** See `docs/flutter-employee-shift-schedule-screen-guide.md` in the repo for full API contracts and flows.
>
> Match existing app architecture (Riverpod/Bloc/your pattern), API client, and theme.

---

## 11. Testing the integration

### Manual smoke test (demo tenant)

After backend migration V020 and demo seed:

1. Login as demo admin
2. `GET /v1/branches` — pick Head Office branch id
3. `GET /v1/scheduling/board/today?branch_id=...`
4. Verify employees appear with mixed statuses
5. `PUT /v1/scheduling/assignments` — change one cell, refresh board
6. `POST /v1/scheduling/copy-week` — copy a week, verify new overrides

Demo seed scenarios (see `004_demo_rates_scheduling_geofence.sql`):

- **DEMO-E04** — unassigned (no recurring schedule)
- **Employee1** — daily override on 2026-06-23 (early shift)
- **Employee2** — leave 2026-06-24 to 2026-06-25

### Widget tests (suggested)

- Cell renders correct color for each `ShiftStatus`
- Conflict badge visible when `conflicts.isNotEmpty`
- Edit actions hidden when `canManage == false`
- Week navigation updates `start`/`end` query params

---

## 12. Performance notes

- Prefer **one board call** per view over per-employee calls
- Cache `templates` list for pickers (invalidate on template CRUD)
- Week range should stay ≤ 14 days for smooth mobile scrolling
- Use `board/today` for dashboard widgets or home screen shortcut

---

## 13. Related files in repo

| File | Purpose |
|------|---------|
| `docs/employee-shift-schedule-backend-implementation.md` | Full backend implementation details |
| `docs/RBAC_PERMISSIONS_AND_ROUTES.md` | Permission and route reference |
| `timesheet-backend/app/modules/scheduling/schemas.py` | Source of truth for JSON field names |
| `timesheet-backend/app/modules/scheduling/router.py` | All endpoint paths |
| `timesheet-db/migrations/V020__shift_schedule_board.sql` | Database schema |
