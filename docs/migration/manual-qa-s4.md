# Manual QA — S4 Engagements / workforce

**Depends on:** S0–S3  
**API blockers:** [BH-002](./backend-handoff-contractor-register-nested-txn.md)–[BH-004](./backend-handoff-contractor-register-nested-txn.md) for full contractor funnel

---

## 0. Prerequisites

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=TERMS_VERSION=v0.1-placeholder \
  --dart-define=PRIVACY_VERSION=v0.1-placeholder \
  --dart-define=DOMAIN_V2=true
```

| Role | Credential |
|------|------------|
| Staff | `admin@demotenant.example` / `ChangeMe123!` |
| Contractor | Register via S1 (unique email) |

---

## S4-1 Staff invite

- [ ] Staff → **Workforce** (`/staff/workforce`) — list loads (`GET /v1/tenants/current/engagements`).
- [ ] Status filter chips use API strings: `invited`, `pending_docs`, `approved`, `active`, `suspended`, `ended`.
- [ ] **Invite** → email and/or phone + multi-select required categories (allowlist).
- [ ] Submit → `POST /v1/tenants/current/engagements` → **201**; row appears as `invited`.
- [ ] Missing email+phone or empty categories → validation message (no crash).

---

## S4-2 Contractor accept (onboarding)

- [ ] Contractor logs in (after invite) → onboarding → reach **Engagement** step.
- [ ] Invited engagement listed with provider name + required categories.
- [ ] **Accept** opens grant UI:
  - Explains sharing metadata with **named provider**
  - Toggle `allow_source_evidence` with warning
  - Checkbox for withdrawal / end-engagement effects
- [ ] Confirm → records legal-event `consented` with `engagement_id`, then `POST .../accept` `{ allow_source_evidence }`.
- [ ] Status becomes `pending_docs` (not a fictional `accepted` label).
- [ ] Continue blocked while any invite remains `invited`.

---

## S4-3 Credentials + staff review (smoke with S3)

- [ ] Contractor uploads required credentials / evidence (S3).
- [ ] Staff opens engagement detail → **Review credentials** (pre-filled contractor + engagement ids).
- [ ] Review decisions succeed when MFA not required (or MFA banner when `mfa_required`).

---

## S4-4 Approve / activate + eligibility

- [ ] From detail while `pending_docs`: **Approve** and/or **Approve & activate**.
- [ ] If requirements incomplete → `eligibility_incomplete` with **itemised** panel (no “NDIS certified” / “Verified by Rostiq” copy).
- [ ] When eligible → status `approved` then **Activate** → `active` (or combined action).
- [ ] **Suspend** / **Resume** / **End** honour permissions (`contractors.manage`).

---

## S4-5 Legacy employee CRUD removed

- [ ] `/admin/employees`, create-employee, employee detail routes are gone (404 / not registered).
- [ ] Legacy admin panel “Employees” navigates to **Staff Workforce** (or equivalent).
- [ ] Employee picker still reachable from legacy payment/payroll if those screens are open.

---

## Exit

Smoke path possible: **invite → register → onboarding accept → credentials → staff review → approve → activate**.
