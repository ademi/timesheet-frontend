# Manual QA — S7 Visits + check-in/complete

**Depends on:** S0 dual shells, S6 jobs/recurrence (to generate visits)  
**Error codes:** `geofence_rejected`, `forms_incomplete` / `required_forms_incomplete`, `scan_blocked`, `engagement_not_active` (mapped in `AppFailure`)

---

## 0. Prerequisites

```bash
# Web (check-in buttons disabled)
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=DOMAIN_V2=true

# Mobile (GPS check-in/complete)
flutter run -d <device> \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=DOMAIN_V2=true
```

| Role | Credential |
|------|------------|
| Staff | `admin@demotenant.example` / `ChangeMe123!` |
| Contractor | Active engagement JWT with `visits.check_in` / `visits.complete` |

Generate at least one visit via S6 recurrence **Generate** or manual visit.

**Legacy check:** `/home` redirects to `/staff/visits`; admin hub no longer shows Attendance Report / Corrections.

---

## S7-1 Staff visits board

- [ ] Staff → **Visits** (`/staff/visits`) loads `GET /v1/visits?from=&to=` (7-day window).
- [ ] Week navigator shifts range ±7 days.
- [ ] Optional `job_id` filter + status filter refresh the list.
- [ ] From job detail → **Open visits for this job** applies `job_id` arg.
- [ ] Open a row → detail refreshes via `GET /v1/visits/{id}`.

---

## S7-2 Staff reschedule / cancel

- [ ] With `visits.manage`, **Reschedule (+1 hour)** → `PATCH /v1/visits/{id}`.
- [ ] **Cancel visit** → `POST /v1/visits/{id}/cancel`; status becomes cancelled.

---

## S7-3 Contractor list / detail

- [ ] Contractor → **Visits** lists upcoming visits (scoped to self).
- [ ] Detail shows schedule, geofence mode, tasks, form requirements (if API returns them).

---

## S7-4 Web GPS policy

- [ ] On Chrome/web: Check in / Complete buttons **disabled**.
- [ ] Banner: “Check-in requires the mobile app with location enabled”.

---

## S7-5 Mobile check-in / complete

- [ ] On device: Check in → GPS `{ lat, lng, accuracy_m? }` + header `Idempotency-Key: checkin-{id}`.
- [ ] Status → `checked_in`.
- [ ] Toggle tasks → `PATCH .../tasks/{task_id}` `{ is_done }`.
- [ ] Submit required form (after check-in) → `POST .../form-submissions`.
- [ ] Complete → same GPS body + `Idempotency-Key: complete-{id}` → `completed`.

---

## S7-6 Error handling

- [ ] Outside enforced geofence → inline `geofence_rejected` message.
- [ ] Complete without required forms → `forms_incomplete` / `required_forms_incomplete`.
- [ ] Blocked scan docs → `scan_blocked`.
- [ ] Non-active engagement check-in → `engagement_not_active`.

---

## Exit

S7 exit met when staff can board/filter/reschedule/cancel visits, and a contractor on mobile can check in, complete tasks/forms, and complete with GPS + Idempotency-Key; web blocks GPS actions with the mobile-app message.
