# Manual QA — S6 Jobs + forms + recurrence

**Depends on:** S0 (staff shell), S4 (engagements for contractor picker), S5 (clients/sites for job location)  
**Backend follow-ups:** [BH-008](./backend-handoff-contractor-register-nested-txn.md), [BH-009](./backend-handoff-contractor-register-nested-txn.md)

---

## 0. Prerequisites

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=DOMAIN_V2=true
```

| Role | Credential |
|------|------------|
| Staff | `admin@demotenant.example` / `ChangeMe123!` |

Staff JWT needs `jobs.read` / `jobs.manage`, plus `clients.read`/`clients.manage` for form templates, and an active/approved engagement for recurrence contractor pick. Sites used as job locations should have lat/lng (BH-006).

**Legacy check:** `/admin/shift-schedule` and admin hub “Shift Schedule” card are gone (S6 delete).

---

## S6-1 Jobs list / create (XOR location)

- [ ] Staff → **Jobs** (`/staff/jobs`) loads `GET /v1/jobs`.
- [ ] **Add job** → title, kind (`standing`|`ad_hoc`), location mode site **or** branch (not both).
- [ ] Standing requires client; site mode requires a site from that client.
- [ ] Create → `POST /v1/jobs` **201**; appears in list.
- [ ] Site without coords may fail with `client_site_missing_location` — expected until BH-006.

---

## S6-2 Job detail — status + form catalog

- [ ] Open job → detail shows kind/status/location/geofence.
- [ ] Close / Cancel → `PATCH /v1/jobs/{id}` with status.
- [ ] Attach form template → `POST /v1/jobs/{id}/form-catalog`.
- [ ] Attached IDs only remembered in-session (BH-009 — no GET catalog).
- [ ] Web refresh on detail cannot reload job by id (BH-008).

---

## S6-3 Form templates

- [ ] Jobs app bar → form templates (`/staff/jobs/form-templates`).
- [ ] Create name → `POST /v1/form-templates` with simple `{fields:[{id,type,label}]}` schema.
- [ ] List → `GET /v1/form-templates?tenant_level=true`.
- [ ] Delete → `DELETE /v1/form-templates/{id}` (needs `clients.manage`).

---

## S6-4 Recurrence + generate

- [ ] On a **standing** job, add rule: contractor, RRULE, duration, optional tasks/forms.
- [ ] Create → `POST /v1/jobs/{id}/recurrence-rules`.
- [ ] Activate/deactivate → `PATCH .../recurrence-rules/{rule_id}`.
- [ ] **Generate (14d)** with optional `partial` → `POST .../generate` + header `Idempotency-Key`.
- [ ] Snackbar / result shows created + skipped counts.
- [ ] Retry same window reuses same Idempotency-Key (stable for from/to/partial).

---

## S6-5 Manual visit (optional)

- [ ] With `visits.manage`, create manual visit → `POST /v1/jobs/{id}/visits`.
- [ ] Visit board itself is S7 — snackbar acknowledges create only.

---

## Exit

S6 exit met when staff can create a standing job at a site/branch, attach a form template, add a recurrence rule, and generate visits with Idempotency-Key against local API.
