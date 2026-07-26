# Manual QA — S9 Rate bands + payment batches

**Depends on:** S4 engagements, S7 completed unpaid visits  
**Backend note:** [BH-010](./backend-handoff-contractor-register-nested-txn.md)

---

## 0. Prerequisites

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=DOMAIN_V2=true
```

| Role | Needs |
|------|--------|
| Staff | `payments.view` / `payments.manage`; `tenants.manage` for settings write |
| Contractor | `visits.read` or `payments.view_own` |

Have at least one **completed + unpaid** visit and an active engagement.

**Legacy check:** `/payroll/*` and old `/payments` routes are gone; admin hub Payroll card removed.

---

## S9-1 Staff rate bands

- [ ] Staff → **Payments** → **Rate bands**.
- [ ] Pick engagement → `GET /v1/payroll/engagement-rates/{engagement_id}`.
- [ ] Enter base (+ optional evening/night/weekend/PH) and windows → **Save**.
- [ ] `POST .../engagement-rates/{id}` with `hourly_rate` + `bands` (BH-010).
- [ ] New rate appears; prior open rate ends (API behaviour).

---

## S9-2 Payment batches

- [ ] **Create batch** tab lists completed unpaid visits.
- [ ] Select visits + period label → create → `POST /v1/payment-batches` + Idempotency-Key.
- [ ] **Batches** tab lists drafts; open detail shows lines + `band_breakdown` when present.
- [ ] **Post** → visits become paid; **Void** (posted) resets unpaid.

---

## S9-3 Contractor payments

- [ ] Profile → **My payments** (`/contractor/payments`).
- [ ] Filter unpaid/paid → `GET /v1/visits?payment_status=`.

---

## S9-4 Settings

- [ ] Staff → **Settings** loads `GET /v1/tenants/{tenant_id}`.
- [ ] Edit timezone / public holiday jurisdiction (if exposed) → `PATCH` with `tenants.manage`.

---

## Exit

S9 exit met when staff can set engagement rate bands, create/post/void payment batches (with line breakdown when API sends it), contractors can filter visit payment status, and tenant timezone/jurisdiction is editable when available.
