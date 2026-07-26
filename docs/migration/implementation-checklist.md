# Flutter Migration — Implementation Checklist

**Purpose:** Day-to-day implementation checklist for the contractor-domain Flutter app.  
**Authoritative design:** [2026-07-23-frontend-contractor-domain-restructure-design.md](./2026-07-23-frontend-contractor-domain-restructure-design.md)  
**Delta vs prior Phase 1–2 docs:** [design-delta-2026-07-26.md](./design-delta-2026-07-26.md)  
**API helpers:** [frontend-api-wiring-guide.md](./frontend-api-wiring-guide.md) · live `{BASE}/docs` · [phase1/api-path-inventory.md](./phase1/api-path-inventory.md)

**How to use:** Deliver **S0 → S10** in order. Each slice must leave the app runnable. Delete listed legacy at end of the slice that replaces it. Do not invent endpoints.

---

## Decisions locked (Flutter design §1 + product)

| Topic | Decision |
|-------|----------|
| Product | Contractor-only greenfield shell — do not preserve employee clock/CRUD/old shift/old payroll-period UX |
| Packaging | One app, two shells: **StaffShell** (`tenant_member`) + **ContractorShell** (`contractor`) |
| State | Keep **GetX** |
| Platforms | Web + mobile every V1 screen; GPS check-in mobile-only (web message) |
| Landing vs Flutter | Flutter: contractor register + authenticated product. Landing: company register + GoCardless. Flutter deep-links billing |
| Legacy | **Delete** as each slice lands — no `lib/legacy/` |
| Delivery | Skeleton-first, then vertical slices S0–S10 |
| Out of V1 | Records-engine, company register UI, in-app checkout, retention UI, platform.admin console, rebrand |

### Known gaps (implement defensively)

| Gap | Flutter handling |
|-----|------------------|
| No public legal-doc read for register | `TERMS_VERSION` / `PRIVACY_VERSION` + bundled markdown; re-fetch after login |
| Suspended JWT vs complete | Clear suspended UX; handle 403 on complete |
| No contractor own payment-batches list | `GET /visits?payment_status=` |
| Seed = roles only | Manual fixtures for dogfood |

---

## Discovery archive (complete — do not re-open)

Phase 1 contract freeze (2026-07-23) remains valid as discovery evidence:

- [x] Clarification answers · OpenAPI spot-check · scope/errors/cutover · contract spikes  
- See [phase1/](./phase1/) and [design-delta-2026-07-26.md](./design-delta-2026-07-26.md) for updates after the Flutter restructure design.

Prior “Phase 2” scaffolding under `lib/app/` is a **partial S0 prototype** — realign to `lib/features/` in S0.

---

## S0 — Skeleton (folder layout, session, shells, guards)

**Goal:** Runnable dual-shell app; login → Staff or Contractor home; web refresh keeps session.  
**Design:** §3, §4, §9 S0

- [x] Create `lib/features/`, `lib/shared/`; move toward layout in design §3.1
- [x] Single `ApiClient` path plan (stop adding `AttendanceApiClient` usage)
- [x] `api_paths.dart` (or equivalent) from design §7 — no legacy employee/scheduling paths
- [x] `SessionService`: after login/refresh/switch-tenant/resume → `GET /v1/auth/me/context`; expose `isStaff` / `isContractor` / `hasPermission` (incl. `*` / `platform.admin`)
- [x] `AppFailure` + error mapper: 401, 403 codes, **billingGate** (402 / subscription), `eligibility_incomplete`, `proxy_required`, 429
- [x] Dart-defines: `API_BASE_URL`, `BILLING_URL`, `LANDING_URL`, `TERMS_VERSION`, `PRIVACY_VERSION`
- [x] Gateway: Sign in · Register as contractor · optional Provider signup → `LANDING_URL` — **delete** admin/attendance role cards
- [x] Empty **StaffShell** (`/staff/...`) + **ContractorShell** (`/contractor/...`) with nav from §4.3–4.4
- [x] Guards: `AuthGuard`, `ActorGuard`, `PermissionGuard` (anyOf/allOf)
- [x] Post-login algorithm from design §4.2 (staff home / contractor onboarding or home)
- [x] Deprecate/remove `/v2/admin/*` and `/v2/contractor/*` stub routes once `/staff` + `/contractor` exist
- [x] Unit: SessionService routing + permission helper

**S0 exit:** Staff login → Staff home; contractor login → Contractor home (or onboarding stub); logout → gateway; web refresh OK; `flutter analyze` clean on touched code.

**Delete when done:** Gateway `UserRole.admin` / `attendance` model. ✅ removed from gateway (legacy branch gateway still reads stored `role` string until that slice is deleted).

---

## S1 — Contractor register

**Design:** §6.2, §15

- [x] `/contractor/register` form: full_name, email, password, phone?, dob?
- [x] Separate Terms + Privacy accept (bundled MD + version defines; `doc_key`s `platform_terms` / `privacy_policy`)
- [x] `POST /v1/contractors/register` with `terms_version`, `privacy_version` → navigate to **login** (no tokens)
- [x] Wire gateway “Register as contractor”

**S1 exit:** Public register → login works against local API.

**Note (local dogfood):** Flutter S1 UI/API client is wired. If `POST /v1/contractors/register` still returns 500, restart the backend after the nested-transaction fix in `contractors/service.py`, and ensure `platform_terms` / `privacy_policy` versions exist (seed `v0.1-placeholder` or matching `--dart-define=TERMS_VERSION` / `PRIVACY_VERSION`).

---

## S2 — Compliance legal + onboarding funnel shell

**Design:** §5.1–5.2, §6.3

- [x] Legal docs fetch (`GET /v1/compliance/legal-documents/current?doc_key=`)
- [x] Legal events: presented → accepted (separate); notices acknowledged; consents
- [x] `flutter_markdown` read-only; counsel_pending hard-stop
- [x] Onboarding routes `/contractor/onboarding/*` outside tab chrome
- [x] Steps: legal → notices → consents → (accept stub) → (credentials stub)
- [x] Idempotency-Key on legal-event retries

**S2 exit:** Contractor after login can complete legal/notice steps; cannot skip accept.

**Blocked for full dogfood until API:** [BH-002](./backend-handoff-contractor-register-nested-txn.md) (login without engagement) · [BH-003](./backend-handoff-contractor-register-nested-txn.md) (compliance perms on invited/pending). Manual steps: [manual-qa-s2.md](./manual-qa-s2.md).

---

## S3 — Credentials + documents

**Design:** §5.3–5.4, §5.6, §6.4

- [x] Credential types allowlist + sensitive / government-ID UX
- [x] Contractor credentials CRUD + supersede
- [x] Upload: upload-url → PUT → finalize `{ credential_id }` → poll scan
- [x] Download: signed URL vs **`/content` proxy** on `proxy_required`
- [x] Staff metadata list + review (`accepted|rejected|re_review_required`); MFA prompt if required
- [x] Eligibility incomplete itemised UI (no forbidden NDIS-certifying copy)

**S3 exit:** Upload + scan states + proxy download helper implemented. Manual QA: [manual-qa-s3.md](./manual-qa-s3.md).  
**Blocked for full dogfood until API:** [BH-004](./backend-handoff-contractor-register-nested-txn.md) (credentials perms on invited/pending) · also BH-002 / BH-003 for reaching the funnel.

---

## S4 — Engagements / workforce

**Design:** §5.5, §6.5

- [x] Staff workforce list/detail; invite with `required_categories`
- [x] Lifecycle: approve / activate / approve-and-activate / suspend / resume / end
- [x] Contractor accept with `allow_source_evidence` grant UI
- [x] Wire onboarding engagement-accept step
- [x] Eligibility errors on approve

**Delete when done:** Employee management screens/controllers/repos (as replaced) — list/create/detail CRUD removed; picker retained temporarily for legacy payroll/payment flows.

**S4 exit:** Invite → register → onboarding → accept → staff review → approve → activate smoke path possible (API blockers BH-002–BH-004 may still block dogfood). Manual QA: [manual-qa-s4.md](./manual-qa-s4.md).

---

## S5 — Clients CRM

**Design:** §6.6, §4.1 invites

- [x] Clients / sites / contacts CRUD
- [x] Create invite token UI
- [x] Public `/invites/client/:token` acknowledge screen (+ `/invite/:token` alias for BH-005)
- [x] Map/pin or lat/lng for sites (lat/lng required in Flutter UI)

**Not in V1:** NDIS client packs / records-engine · interactive map pin (coords entry only).

**S5 exit:** Client + site + contact + invite create + public acknowledge smoke path. Manual QA: [manual-qa-s5.md](./manual-qa-s5.md).  
**Backend follow-ups:** [BH-005](./backend-handoff-contractor-register-nested-txn.md) (invite URL path) · [BH-006](./backend-handoff-contractor-register-nested-txn.md) (require site coords) · [BH-007](./backend-handoff-contractor-register-nested-txn.md) (optional invite list).

---

## S6 — Jobs + forms + recurrence

**Design:** §6.7

- [x] Jobs list/create/edit; form-catalog attach
- [x] Form templates list/CRUD (staff) as needed for jobs/visits
- [x] Recurrence rules + generate (`Idempotency-Key`; `partial` optional)
- [x] Location XOR `branch_id` / `client_site_id`

**Delete when done:** Shift schedule employee board feature. ✅ removed (`/admin/shift-schedule` + widgets/controller/binding)

**Manual QA:** [manual-qa-s6.md](./manual-qa-s6.md)  
**API gaps:** [BH-008](./backend-handoff-contractor-register-nested-txn.md) (no GET job by id) · [BH-009](./backend-handoff-contractor-register-nested-txn.md) (no GET form-catalog)

---

## S7 — Visits + check-in/complete

**Design:** §6.8

- [x] Staff visits board (`from`/`to`/`job_id`/…)
- [x] Contractor visits list/detail; tasks; form submissions
- [x] Check-in / complete GPS body `{ lat, lng, accuracy_m? }` + Idempotency-Key
- [x] Web: disable check-in/complete with mobile-app message
- [x] Geofence / forms_incomplete / scan_blocked / engagement_not_active handling

**Delete when done:** Employee attendance clock + obsolete attendance report/corrections product screens. ✅ removed (`/home` clock redirects to staff visits; report/corrections/adjustment routes + hub cards deleted)

**Manual QA:** [manual-qa-s7.md](./manual-qa-s7.md)

---

## S8 — Contractor schedule

**Design:** §6.9

- [x] Timetable / availability / leave
- [x] Copy: preferences only — do not create visits

**Manual QA:** [manual-qa-s8.md](./manual-qa-s8.md)

---

## S9 — Rate bands + payment batches

**Design:** §6.10

- [x] Engagement rate bands editor (base/evening/night/weekend/PH)
- [x] Payment batches create/post/void; show `band_breakdown`
- [x] Contractor payments via visits `payment_status` filter
- [x] Settings: timezone / `public_holiday_jurisdiction` when available

**Delete when done:** Old payroll periods / employee rates / period-tied payments. ✅ routes removed from `app_pages` (legacy views unreferenced); StaffShell `/staff/payments` + `/staff/settings` replace them.

**Manual QA:** [manual-qa-s9.md](./manual-qa-s9.md)  
**API note:** [BH-010](./backend-handoff-contractor-register-nested-txn.md) — rate create body sends bands + `hourly_rate` (compat); confirm live OpenAPI.

---

## S10 — Compliance ops + notifications + subscription + cleanup

**Design:** §6.11–6.14, §9 S10

- [ ] Rights requests, privacy export, access history, incidents
- [ ] Notifications devices/events retarget for both actors
- [ ] Subscription status + `BILLING_URL` deep-link on billingGate
- [ ] Staff settings: members, branches as needed, billing chip
- [ ] Delete remaining employee leftovers, `AttendanceApiClient`, PIN paths
- [ ] `flutter analyze` clean; smoke §10.2

---

## Progress tracker

| Slice | Name | Exit met? |
|-------|------|-----------|
| Discovery | Phase 1 archive | [x] |
| S0 | Skeleton / session / shells | [ ] *(partial prototype in `lib/app` — realign)* |
| S1 | Contractor register | [ ] |
| S2 | Legal + onboarding | [ ] |
| S3 | Credentials + documents | [ ] |
| S4 | Engagements / workforce | [ ] |
| S5 | Clients CRM | [x] |
| S6 | Jobs + recurrence | [x] |
| S7 | Visits + GPS | [x] |
| S8 | Contractor schedule | [x] |
| S9 | Rates + batches | [x] |
| S10 | Compliance ops + cleanup | [ ] |

---

## Suggested next actions

1. [ ] Start **S0**: `features/` layout + `SessionService` + `/staff` & `/contractor` shells + gateway rewrite  
2. [ ] Port reusable Phase 2 pieces (`JwtClaims`, switch-tenant, DocumentService spike, AppPermissions) into new structure  
3. [ ] Then S1 contractor register  

---

*Update checkboxes as slices complete. Prefer the Flutter restructure design over older Phase 3+ wording in archived docs.*
