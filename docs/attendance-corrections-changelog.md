# Attendance Corrections — What's New

This document summarizes the new **Attendance Corrections** feature for the
Yemen Gate timesheet system. It covers what changed on the server (backend) and
what was added in the mobile app (frontend), plus a short guide for admins.

_Last updated: 2026-06-14_

---

## 1. Overview

Employees clock in and out using their 4-digit PIN. Sometimes an employee
forgets to punch (no clock-in, no clock-out, or both) or punches at the wrong
time. Previously there was no way to fix this from the app.

We added an **admin-only correction tool**:

- Admins can review attendance problems ("exceptions") in one place.
- Admins can add a missing clock-out, create a full entry, or edit existing
  times.
- Every correction requires a written **reason** and is recorded in an audit
  trail.

**Important:** Admin corrections are **final**. There is no employee
confirm/reject step, and there is no "super PIN". Employee PIN punches remain
the proof of presence; admin corrections are a separate, accountable action.

---

## 2. Backend Changes

### New / updated endpoints

| Purpose | Endpoint |
| --- | --- |
| Review queue (attendance problems) | `GET /v1/attendance/exceptions?from=...&to=...&branch_id=...` |
| Submit a correction | `POST /v1/attendance/adjustments` |
| Correction audit trail | `GET /v1/attendance/time-entries/{time_entry_id}/adjustments` |
| Time entries now include source fields | `GET /v1/attendance/time-entries` |

### Exception types in the review queue

- `missing_clock_out` — employee clocked in but never clocked out.
- `manual_adjustment` — entry was created/edited by an admin.
- `long_shift` — shift is unusually long and should be reviewed.
- `needs_review` — other cases flagged for attention.

> The backend cannot detect a missing clock-in on its own (there is no record to
> flag), so the admin creates those entries manually from evidence.

### Correction actions (`POST /v1/attendance/adjustments`)

Every action requires a non-empty `reason`.

1. **`admin_add_clock_out`** — employee forgot to clock out (an open entry
   exists). Adds the missing clock-out; entry becomes `closed`.
2. **`admin_create_manual_entry`** — employee forgot the clock-in (or both
   punches). Admin creates the full corrected entry.
3. **`admin_edit_entry`** — an existing entry has the wrong time(s). Either the
   clock-in or clock-out can be changed.

### Time entry display fields

Time entries now return:

- `clock_in_source` / `clock_out_source` — e.g. `employee_pin` or
  `admin_adjustment`.
- `anomaly_flag` — `true` when the entry should be reviewed.

### Removed

- The earlier **employee confirmation flow** (`employee_confirm` /
  `employee_reject` and the `pending_employee_confirmation` status) was
  **removed**. Corrections no longer wait for employee approval.

---

## 3. Frontend (Mobile App) Changes

### Admin panel

- Added a new card on the Admin panel: **"Attendance Corrections"**
  ("Review exceptions and fix missing punches").

### Attendance Corrections — review queue

- Choose a **date range (From / To)** and load all attendance exceptions for the
  branch.
- Each item shows the employee name, clock-in/out times, and a colored
  **status badge** (Missing clock-out, Manual adjustment, Long shift, Needs
  review).
- A **warning marker** appears when an entry is flagged as an anomaly.
- Times that came from an admin correction show a small **"manual"** tag.
- Each item has two actions:
  - **Correct** — opens the correction form (pre-filled for the right case).
  - **History** — shows the audit trail of all changes to that entry.
- A **"Manual Entry"** button lets the admin pick an employee and create a brand
  new entry (used when the employee forgot to clock in).

### Correction form

The form adapts to the situation:

- **Missing clock-out** → only the clock-out time is requested (existing
  clock-in is shown for reference).
- **Manual entry** → both clock-in and clock-out times are requested.
- **Edit entry** → both times are pre-filled and editable.

In all cases:

- A **Reason** is required.
- The app validates that clock-out is after clock-in.
- On success, the admin sees "Correction saved successfully" and the entry is
  final (no employee approval needed).

### Employee punch screen

- If an employee tries to **clock out without an active clock-in**, instead of a
  technical error they now see a clear message:
  > "No active clock-in found. Please contact your admin to correct your
  > attendance."

### Not built (by design)

- No employee confirm/reject screens.
- No super-PIN flow.

---

## 4. How Admins Use It (Quick Guide)

1. Open the **Admin panel** and tap **Attendance Corrections**.
2. Pick a **From** and **To** date and tap search to load exceptions.
3. Find the employee/day that needs fixing and tap **Correct**:
   - Forgot to clock out → set the **clock-out** time.
   - Wrong time on an existing entry → use **Correct** and adjust the times.
4. If the employee **forgot to clock in** (no record exists), tap
   **Manual Entry**, choose the employee, and enter both times.
5. Always type a clear **reason** (e.g. "Manager confirmed end time"), then
   submit.
6. Use **History** on any entry to see who changed what and when.

---

## 5. Developer Notes (Files Changed)

For the technical team, the mobile changes live in:

- **Models:** `time_entry_out.dart` (source/anomaly fields),
  `attendance_exception_model.dart`, `attendance_adjustment_request.dart`,
  `attendance_adjustment_response.dart`, `attendance_adjustment_history.dart`
- **Data access:** `attendance_remote_datasource.dart`,
  `attendance_repository.dart`
- **Screens & logic:** `attendance_corrections_controller.dart` +
  `attendance_corrections_view.dart`, `attendance_adjustment_controller.dart` +
  `attendance_adjustment_view.dart`
- **Wiring/DI:** `attendance_module_binding.dart`,
  `attendance_corrections_binding.dart`, `attendance_adjustment_binding.dart`,
  `app_routes.dart`, `app_pages.dart`, `route_args.dart`,
  `admin_panel_controller.dart`, `admin_panel_view.dart`
- **Employee punch message:** `attendance_controller.dart`

The employee clock-in/clock-out request body was intentionally left unchanged.
