# Manual QA — S8 Contractor schedule

**Depends on:** S0 contractor shell, S7 visits (timetable shows assigned visits)  
**Actor:** `contractor` JWT only (`/v1/contractor-me/*`)

---

## 0. Prerequisites

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=DOMAIN_V2=true
```

Contractor needs `auth.session`. To edit availability/leave: `contractor.schedule.manage`.

---

## S8-1 Timetable

- [ ] Contractor → **Schedule** (`/contractor/schedule`) opens with preferences banner.
- [ ] **Timetable** tab loads `GET /v1/contractor-me/timetable?from=&to=` (7-day window).
- [ ] Week navigator ±7 days refreshes visits.
- [ ] Visit rows show tenant/status/times; tap → Visits tab.

---

## S8-2 Availability

- [ ] **Availability** tab loads `GET /v1/contractor-me/availability`.
- [ ] Toggle weekdays (0=Mon … 6=Sun) and set start/end `HH:MM`.
- [ ] **Save availability** → `PUT /v1/contractor-me/availability` with `{ rules: [...] }`.
- [ ] Snackbar reminds: preferences only — does **not** create visits.
- [ ] Without `contractor.schedule.manage`: controls read-only.

---

## S8-3 Leave

- [ ] List → `GET /v1/contractor-me/leave`.
- [ ] Add leave (YYYY-MM-DD start/end, type, notes) → `POST /v1/contractor-me/leave`.
- [ ] Snackbar: leave does **not** create or cancel visits.
- [ ] Delete → `DELETE /v1/contractor-me/leave/{id}`.

---

## Exit

S8 exit met when a contractor can view timetable visits and manage availability/leave with clear “preferences only” copy — no visit creation from schedule screens.
