# Mobile Attendance Adjustments

This document describes the mobile attendance correction flow.

## Principle

Employee PIN punches are proof of presence. Admin corrections are final admin actions. Employees do not confirm or reject corrections.

- Employee normal flow: `POST /v1/attendance/clock-in` and `POST /v1/attendance/clock-out`
- Admin correction flow: `POST /v1/attendance/adjustments`
- Admin review queue: `GET /v1/attendance/exceptions`

Do not build a super PIN flow. Do not build employee correction approval screens.

## Permissions

- Employee punch: `attendance.punch`
- Employee own time entry read: `attendance.view_own`
- Admin review and correction: `attendance.view` and `attendance.override`

`attendance.confirm_own` is not used by this correction flow.

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

If the employee forgot clock-in and tries to clock-out, the backend can return `404` with `No open time entry to close`. The app should tell the employee to contact the admin.

## Admin Review Queue

Admin screens should call:

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
- `manual_adjustment`
- `long_shift`
- `needs_review`

The backend cannot detect `missing_clock_in` or `missing_both` without a time entry. Admin creates those from employee/manager evidence using `admin_create_manual_entry`.

## Admin Adjustment Endpoint

All corrections use:

```http
POST /v1/attendance/adjustments
```

Every admin action requires a non-empty `reason`.

### Employee Forgot Clock-Out Only

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
  "status": "closed",
  "created_at": "2026-06-14T12:00:00Z"
}
```

### Employee Forgot Clock-In Only

Because no open time entry exists, admin creates the full corrected entry from evidence.

```json
{
  "action": "admin_create_manual_entry",
  "employee_id": "employee-id",
  "clock_in_at": "2026-06-14T09:00:00Z",
  "clock_out_at": "2026-06-14T17:00:00Z",
  "reason": "Employee forgot clock-in; end time confirmed by manager"
}
```

### Employee Forgot Both Clock-In and Clock-Out

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

### Admin Edits an Existing Entry

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

## Time Entry Display Fields

`GET /v1/attendance/time-entries` returns source fields:

```json
{
  "id": "time-entry-id",
  "employee_id": "employee-id",
  "clock_in_at": "2026-06-14T09:00:00Z",
  "clock_out_at": "2026-06-14T17:00:00Z",
  "status": "closed",
  "clock_in_source": "admin_adjustment",
  "clock_out_source": "admin_adjustment",
  "anomaly_flag": true
}
```

Display guidance:

- Show `employee_pin` as normal employee punch.
- Show `admin_adjustment` with an admin/manual correction badge.
- Show `anomaly_flag: true` as a warning or review marker.
- Do not show employee confirm/reject buttons.

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

For admin-only corrections, `employee_confirmation_status` is returned as `confirmed` because the admin has final authority.
