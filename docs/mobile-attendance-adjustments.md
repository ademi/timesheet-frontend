# Mobile Attendance Adjustments

This document describes the attendance correction flow for the mobile app after adding admin manual adjustments.

## Principle

Employee PIN punches are proof of presence. Admin users must not use a super PIN or impersonate the employee.

- Employee normal flow: `POST /v1/attendance/clock-in` and `POST /v1/attendance/clock-out`
- Admin correction flow: `POST /v1/attendance/adjustments`
- Employee approval flow: `POST /v1/attendance/adjustments` with `employee_confirm` or `employee_reject`

## Permissions

- Employee punch: `attendance.punch`
- Employee own confirmation: `attendance.confirm_own`
- Employee own time entry read: `attendance.view_own`
- Admin review and correction: `attendance.view` and `attendance.override`

## Employee Punch Endpoints

Use these only when the employee enters their PIN and is physically clocking in or out.

### Clock In

```http
POST /v1/attendance/clock-in
```

```json
{
  "lat": 15.3694,
  "lng": 44.191,
  "accuracy_m": 12,
  "source": "gps"
}
```

### Clock Out

```http
POST /v1/attendance/clock-out
```

```json
{
  "lat": 15.3694,
  "lng": 44.191,
  "accuracy_m": 12,
  "source": "gps"
}
```

If the employee forgot clock-in and tries to clock-out, the backend can return `404` with `No open time entry to close`. The app should show a message telling the employee to contact the admin.

## Admin Review Queue

Admin app screens should call:

```http
GET /v1/attendance/exceptions?from=2026-06-01&to=2026-06-14&branch_id=<branch_id>
```

`branch_id` is optional.

Example response:

```json
[
  {
    "id": "time-entry-id",
    "employee_id": "employee-id",
    "clock_in_at": "2026-06-14T09:00:00Z",
    "clock_out_at": null,
    "status": "open",
    "clock_in_source": "employee_pin",
    "clock_out_source": null,
    "anomaly_flag": false,
    "exception_type": "missing_clock_out"
  }
]
```

Exception types currently returned:

- `missing_clock_out`
- `pending_employee_confirmation`
- `manual_adjustment`
- `long_shift`
- `needs_review`

The backend cannot detect `missing_clock_in` or `missing_both` without a time entry. The admin creates those from employee/manager evidence using `admin_create_manual_entry`.

## Admin Adjustment Endpoint

All admin corrections use:

```http
POST /v1/attendance/adjustments
```

Every admin action requires a non-empty `reason`.

### Scenario 1: Employee Forgot Clock-Out Only

Use this when there is an existing open time entry.

```json
{
  "action": "admin_add_clock_out",
  "time_entry_id": "time-entry-id",
  "clock_out_at": "2026-06-14T17:00:00Z",
  "reason": "Employee forgot to clock out; manager confirmed end time"
}
```

Response:

```json
{
  "adjustment_id": "adjustment-id",
  "time_entry_id": "time-entry-id",
  "status": "pending_employee_confirmation",
  "created_at": "2026-06-14T12:00:00Z"
}
```

### Scenario 2: Employee Forgot Clock-In Only

Because no open time entry exists, admin creates the full corrected entry from evidence.

```json
{
  "action": "admin_create_manual_entry",
  "employee_id": "employee-id",
  "clock_in_at": "2026-06-14T09:00:00Z",
  "clock_out_at": "2026-06-14T17:00:00Z",
  "reason": "Employee forgot clock-in; clock-out/end time confirmed by manager"
}
```

### Scenario 3: Employee Forgot Both Clock-In and Clock-Out

Use the same manual entry action.

```json
{
  "action": "admin_create_manual_entry",
  "employee_id": "employee-id",
  "clock_in_at": "2026-06-14T09:00:00Z",
  "clock_out_at": "2026-06-14T17:00:00Z",
  "reason": "Employee forgot both punches; shift confirmed by supervisor"
}
```

### Scenario 4: Admin Edits an Existing Entry

Use this when an existing entry has the wrong clock-in or clock-out time.

```json
{
  "action": "admin_edit_entry",
  "time_entry_id": "time-entry-id",
  "clock_in_at": "2026-06-14T09:15:00Z",
  "clock_out_at": "2026-06-14T16:45:00Z",
  "reason": "Corrected from approved attendance sheet"
}
```

`clock_in_at` or `clock_out_at` can be omitted if only one side is changing.

## Employee Confirmation

Admin corrections move the entry to:

```text
pending_employee_confirmation
```

The employee should see pending corrections in their time entry screen and confirm or reject.

### Confirm

```json
{
  "action": "employee_confirm",
  "time_entry_id": "time-entry-id"
}
```

Confirmed entries become:

```text
closed
```

### Reject

```json
{
  "action": "employee_reject",
  "time_entry_id": "time-entry-id",
  "reason": "The suggested clock-out time is wrong"
}
```

For a missing clock-out correction, rejection reopens the entry. For a manual full entry, rejection marks the entry as `rejected`. For an admin edit, rejection restores the previous time entry values.

## Time Entry Display Fields

`GET /v1/attendance/time-entries` now returns source fields:

```json
{
  "id": "time-entry-id",
  "employee_id": "employee-id",
  "clock_in_at": "2026-06-14T09:00:00Z",
  "clock_out_at": "2026-06-14T17:00:00Z",
  "status": "pending_employee_confirmation",
  "clock_in_source": "admin_adjustment",
  "clock_out_source": "admin_adjustment",
  "anomaly_flag": true
}
```

Display guidance:

- Show `employee_pin` as normal employee punch.
- Show `admin_adjustment` with an admin/manual correction badge.
- Show `pending_employee_confirmation` clearly and provide confirm/reject actions for employees.
- Show `anomaly_flag: true` as a warning or review marker.

## Adjustment History

Use this endpoint to show the audit trail:

```http
GET /v1/attendance/time-entries/{time_entry_id}/adjustments
```

The response includes:

- `action`
- `reason`
- `admin_user_id`
- `employee_confirmation_status`
- `old_clock_in_at`
- `old_clock_out_at`
- `new_clock_in_at`
- `new_clock_out_at`
- `created_at`

