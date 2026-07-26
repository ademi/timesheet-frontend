# Manual QA — S10 Compliance ops + notifications + subscription + cleanup

**Depends on:** dual shells (S0+), staff/contractor sessions  
**Design:** §6.11–6.14, §9 S10

---

## 0. Prerequisites

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=DOMAIN_V2=true \
  --dart-define=BILLING_URL=https://example.com/billing
```

| Role | Needs |
|------|--------|
| Staff | `compliance.rights.manage` / `compliance.incidents.manage` / `compliance.audit.view` (as available); `subscription.view` or `billing.view` for chip |
| Contractor | Authenticated contractor session |

**Legacy check:** PIN verify/set gone; `AttendanceApiClient` gone; old employee/payroll/scheduling datasources under `lib/app/data` removed. Product UI is StaffShell / ContractorShell only (admin hub is a thin redirect hub).

---

## S10-1 Staff compliance

- [ ] Staff → **Compliance** (`/staff/compliance`).
- [ ] **Rights** tab lists `GET /v1/compliance/rights-requests` (when permitted).
- [ ] **Access history** loads audit entries.
- [ ] **Incidents** — create with title → `POST /v1/compliance/incidents`; open/close when API allows.
- [ ] **Alerts** tab shows `GET /v1/notifications/events`.
- [ ] Credential review shortcut still opens `/staff/credentials-review`.

---

## S10-2 Contractor profile ops

- [ ] Contractor → **Profile** (`/contractor/profile`).
- [ ] Submit rights request (`access` / `correction` / `deletion` / `export`).
- [ ] Privacy export → `POST /v1/contractor-me/privacy-export` (download/JSON handling as implemented).
- [ ] Consent withdraw dialog (credential type + notes).
- [ ] Recent alerts list; link to **My payments**.

---

## S10-3 Home alerts + subscription chip

- [ ] Staff **Home** and Contractor **Home** load notification events.
- [ ] Staff with billing permission sees subscription status chip + **Billing** opens `BILLING_URL`.
- [ ] Staff **Settings** shows subscription chip + tenant members list when permitted; timezone/jurisdiction save still works (S9).

---

## S10-4 Billing gate

- [ ] Force or simulate `AppFailure.billingGate` (402 / subscription inactive) on a mutating call.
- [ ] Modal: “Subscription inactive” → **Open billing** launches external billing URL.

---

## S10-5 Notifications device register

- [ ] Login registers device (`POST /v1/notifications/devices`) when Firebase is configured (non-fatal if not).
- [ ] Session resume from gateway also attempts register.
- [ ] Logout attempts `DELETE /v1/notifications/devices/{token}`.

---

## Exit

- [ ] Paths above work against live API for demo tenant.
- [ ] `flutter analyze` has **no errors** (infos/warnings OK).
- [ ] Checklist S10 boxes marked done.
