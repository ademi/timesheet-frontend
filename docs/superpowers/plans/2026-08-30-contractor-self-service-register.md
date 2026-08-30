# Contractor self-service register — Product & Engineering Plan

> **Status:** Phase A complete · **waiting for green light before Phase B.**  
> **Rule:** Implement **one phase at a time**. After each phase, stop and wait for explicit approval before starting the next.  
> **Supersedes (partially):** Phase 4 staff “Add contractor” stepper + staff CRM edit from [2026-08-27-contractor-workforce-onboarding.md](./2026-08-27-contractor-workforce-onboarding.md). Phases 0–5 of that plan remain shipped; this plan **pivots** who fills profile data and **removes** staff create/edit paths.  
> **Repos:** Frontend `timesheet-frontend` · Backend `…/flutter backend/timesheet/timesheet-backend` · DB `…/timesheet/timesheet-db`

---

## 1. Goal

Move the **horizontal contractor profile stepper** from staff “Add contractor” to **contractor self-service registration**. Staff return to **invite-only** onboarding. Profile editing moves to the **contractor Profile** screen. Staff workforce detail shows identity/address/screening **read-only**.

**Unchanged:** invite list/re-email, `awaiting_approval` lifecycle, ABN/payment on profile, compliance onboarding funnel (legal/notices/consents/accept engagement), credential uploads (contractor-owned ACL), staff credential review + approve/activate.

---

## 2. Locked decisions (2026-08-30)

| # | Decision | Answer |
|---|----------|--------|
| 1 | When does the stepper run? | **A — entirely before account creation** (pre-auth register flow; submit creates account at end). |
| 2 | Staff workforce detail — profile CRM | **Read-only** display of address, screening, qualifications metadata, checks metadata (no staff edit). |
| 3 | Staff create contractor API | **Remove entirely** (`POST /v1/tenants/current/contractors`, staff `PATCH`, staff create UI). |
| 4 | Mandatory fields at register | **Phase 0 rule:** all optional except **email, password, legal acceptances** (terms + privacy). |
| 5 | ABN + payment | Stay on **Identity / Legal** step at register (same as today’s register extras). |
| 6 | Address lookup | **Automatic geocode** via `POST /v1/public/geocode` on Identity address fields (Phase B). Same confidence/confirm pattern as client onboarding. |
| 7 | Credential evidence uploads | **Not** in register stepper (CRM fields only). Uploads remain in Credentials + compliance funnel. |
| 8 | Staff upload on behalf | **Out of scope** (unchanged). |

---

## 3. Before vs after

| Area | Today (post Phase 5) | After this plan |
|------|----------------------|-----------------|
| Staff workforce FAB | **Add contractor** + **Invite** | **Invite only** |
| Staff onboarding UI | `ContractorOnboardingView` stepper → `POST …/contractors` | **Removed** |
| Staff workforce detail Profile tab | Editable CRM (`PATCH …/contractors/{id}`) | **Read-only** summary |
| Contractor register | Single long scroll form | **Horizontal stepper** (Identity → Screening → Qualifications → Checks → Legal & create account) |
| Contractor profile | Photo, ABN, payment | **Full CRM edit** (identity, address + geocode, screening, quals, checks, ABN/payment) via `PATCH /v1/contractor-me` |
| Invite token `profile` jsonb | Staff pre-fill draft applied on register | **Deprecated for staff pre-fill**; invite carries email + required categories only |
| Backend staff create | `staff_service.create_staff_contractor` | **Removed** |

---

## 4. Target flows

### 4.1 Staff (invite-only)

```
Staff → Invite contractor (email/phone + required doc categories)
  → always email invite (+ backup link in success UI)
  → pending invite appears in workforce list (Re-email)

Contractor registers via invite link → self-service stepper → account created → login

Staff → Workforce detail
  → read-only Identity / Address / Screening / Qualifications / Checks
  → Credentials tab (review evidence)
  → Approve / Approve & activate from awaiting_approval
```

### 4.2 Contractor (register + profile)

```
Invite link (?invite=…) → Register stepper (pre-auth)
  Step 0 Identity     — name, email (from invite), password, phone, DOB, address (+ geocode), ABN, optional payment
  Step 1 Screening    — NDIS screening CRM fields (optional)
  Step 2 Qualifications — 0..N rows (optional)
  Step 3 Checks       — WWCC, police, licence, vehicle CRM (optional)
  Step 4 Legal        — terms + privacy → Create account → POST /v1/contractors/register → auto-login

Post-login (unchanged funnel)
  → skip legal if accepted at register
  → notices → consents → accept engagement
  → upload required credentials
  → pending_docs → awaiting_approval

Profile (contractor shell)
  → edit same domains anytime via PATCH /v1/contractor-me
  → address changes re-use geocode lookup
```

---

## 5. Register stepper steps (contractor)

Mirrors the **chrome** of client onboarding and the former staff stepper (`step` indicator, horizontal labels, Back/Next, mobile-friendly). **No “Invite” step** for contractors.

| # | Step | Fields | Required at submit |
|---|------|--------|-------------------|
| 0 | **Identity** | Full name, email, password, phone, DOB, residential address (line1, line2, suburb, state, postcode, country), ABN, optional payment (account name, BSB, account number) | Email, password only (name recommended in UI copy) |
| 1 | **Screening** | NDIS worker screening number, clearance status, issue/expiry, state/territory | All optional |
| 2 | **Qualifications** | 0..N rows: type, issue/expiry, metadata | All optional |
| 3 | **Checks** | WWCC, police check, driver licence, vehicle reg/insurance CRM | All optional |
| 4 | **Legal & submit** | Terms version, privacy version, accept checkboxes → **Create account** | Legal acceptances required |

**Pre-fill from invite token:** email, required document categories (for post-register credentials UX; shown as read-only hint on final step or home — not a stepper step).

**Document uploads:** not collected in stepper. CRM values stored in `metadata.compliance` (and address columns) at register; evidence uploaded later under Credentials.

---

## 6. Address geocode (Phase B — Identity)

Reuse the **client onboarding site address** pattern:

| Item | Detail |
|------|--------|
| Endpoint | `POST /v1/public/geocode` (`ApiPaths.publicGeocode`) |
| Request | `address_line1`, `city`, `country` (ISO), optional `state` — see `GeocodeRequest` in `client_models.dart` |
| Response | `latitude`, `longitude`, `formatted_address`, `confidence` |
| UX | “Look up address” (or debounced lookup on blur) → show formatted address → user confirms before Next |
| Low confidence | Reject apply (same as `applyGeocodeResponse` in `site_geocode_apply.dart`); show short error, do not advance with bad coords |
| Storage at register | Persist address columns on contractor row; store lat/lng in `metadata` if backend supports (align with client site pattern) |
| Profile edit | Same geocode flow when contractor edits address in Profile |

**Frontend reuse targets**

- `lib/features/clients/utils/site_geocode_apply.dart`
- `lib/features/clients/data/models/client_models.dart` (`GeocodeRequest` / `GeocodeResponse`)
- `ClientsRepository.geocode` or extract to a small shared public geocode client if we want to avoid coupling contractor feature to clients repository

**Out of scope:** browser/device GPS geolocation API; only server-side address geocode.

---

## 7. Architecture sketch

```
Staff: Invite (light) — UNCHANGED
  → POST contractor-invites / engagements invite
  → always email

Contractor: Register stepper (NEW)
  → POST /v1/contractors/register
       (+ address fields, metadata.compliance from steps 1–3)
  → login session

Contractor: Profile (EXPANDED)
  → GET/PATCH /v1/contractor-me (+ payment endpoints)

Staff: Detail (READ-ONLY profile)
  → GET /v1/tenants/current/contractors/{id}  (read only — keep GET, remove POST/PATCH)
  OR embed contractor fields on existing engagement detail if sufficient

REMOVED:
  → POST /v1/tenants/current/contractors
  → PATCH /v1/tenants/current/contractors/{id}
  → Staff ContractorOnboardingView / controller / route / FAB
  → Staff saveStaffProfile on workforce detail
```

---

## 8. Phased delivery

Each phase: **backend + db (if needed) → frontend → tests/smoke → STOP for green light.**

---

### Phase A — Admin rollback (invite-only + read-only detail)

**Why first:** Removes conflicting staff paths before contractors use the new register flow.

**Backend**

- [x] Remove `POST /v1/tenants/current/contractors` (`create_tenant_contractor`).
- [x] Remove `PATCH /v1/tenants/current/contractors/{contractor_id}` (`patch_tenant_contractor`).
- [x] **Keep** `GET /v1/tenants/current/contractors/{contractor_id}` for staff read-only profile (requires `contractors.read`).
- [x] Remove or gut `staff_service.create_staff_contractor`, `patch_staff_contractor` (keep `get_staff_contractor` for read).
- [x] Remove staff-create audit events tied to create/patch only (`contractor_staff_created`, staff profile patch audits) or narrow to invite-only.
- [x] Stop applying invite token `profile` jsonb from staff drafts (field can remain in DB unused, or document deprecated).
- [x] Update/delete tests in `tests/contractors/test_staff_create_permissions.py` (create/patch cases); keep read permission tests if applicable.

**Frontend**

- [x] Remove **Add contractor** FAB and empty-state CTA from `workforce_list_view.dart`.
- [x] Remove route `AppRoutes.staffWorkforceOnboarding`, binding, `ContractorOnboardingView`, `ContractorOnboardingController` under `engagements/`.
- [x] Remove `createStaffContractor` / `patchStaffContractor` from engagements repository/datasource (keep `getStaffContractor`).
- [x] Workforce detail **Profile** tab: remove edit form + Save; render **read-only** sections (identity, address, screening, qualifications, checks) from `getStaffContractor`.
- [x] Keep **Invite contractor** flow unchanged.

**Green light gate:** Staff can only invite; no staff create/edit profile UI; detail shows read-only CRM; backend rejects create/patch. **← waiting for your OK before Phase B.**

---

### Phase B — Contractor register horizontal stepper (+ geocode on Identity)

**Why second:** Core product change — contractor fills profile at signup.

**Backend**

- [ ] Extend `ContractorRegisterRequest` with optional address fields (`address_line1`, `address_line2`, `suburb`, `state`, `postcode`, `country`) and optional `metadata` / structured `compliance` payload (screening, qualifications[], checks).
- [ ] `register_contractor` persists address + merges compliance into `contractors.metadata` (reuse helpers from former `apply_staff_profile_dict` where sensible).
- [ ] Validation: only email/password/legal required; ABN normalized if present; address fields optional.
- [ ] Register tests: minimal register still works; full stepper payload persists address + compliance metadata.

**Frontend**

- [ ] Replace `contractor_register_view.dart` single form with **horizontal stepper** (new controller, e.g. `ContractorRegisterStepperController`).
- [ ] Move/adapt step widgets from `contractor_onboarding_view.dart` → `contractor_register/` (or shared `contractor_profile_steps/` widget module).
- [ ] Step 0 Identity: integrate **`POST /v1/public/geocode`** for address (lookup + confirm + low-confidence gate).
- [ ] Step 4 Legal: terms/privacy + submit → existing register API + login flow.
- [ ] Invite token: load email + required categories; lock email field when invite present.
- [ ] Remove obsolete single-page register layout (or keep redirect for old deep links if any).

**Green light gate:** Contractor opens invite link, completes stepper with geocoded address, creates account, logs in; staff sees read-only profile on detail.

---

### Phase C — Contractor profile expansion (post-login edit)

**Why third:** Parity for updates after register; fold “complete account” gaps into profile where possible.

**Backend**

- [ ] Confirm `ContractorUpdate` / `PATCH /v1/contractor-me` accepts address + `metadata.compliance` (already on schema — add tests if missing).

**Frontend**

- [ ] Expand `ContractorProfileOpsView` + `ContractorProfileController` with sections or sub-steps matching register domains.
- [ ] Extend `ContractorMeRepository.patchMe` to send address + compliance metadata.
- [ ] Address edits use same geocode lookup as register Identity step.
- [ ] Redirect logic: if ABN missing after login, prefer Profile or slim banner → Profile (reduce duplicate `complete_account_view` where safe; keep redirect until profile covers all gaps).

**Green light gate:** Contractor can edit all CRM domains in Profile; changes visible read-only on staff detail.

---

### Phase D — Cleanup, permissions, docs, regression

- [ ] Remove dead code: staff contractor models’ create/update types if unused; staff onboarding tests.
- [ ] Permissions: `contractors.manage` no longer gates staff create/patch (document `contractors.invite` + `contractors.read` for workforce).
- [ ] Update [2026-08-27-contractor-workforce-onboarding.md](./2026-08-27-contractor-workforce-onboarding.md) with pivot note + link here.
- [ ] Update manual test matrix / seed demos.
- [ ] Regression: invite → register stepper → accept engagement → upload docs → `awaiting_approval` → approve.

**Green light gate:** Ready for QA / release.

---

## 9. Field vs upload matrix (register stepper)

Same CRM vs evidence split as the original plan §3; **upload column applies post-register only**.

| Step | CRM fields in stepper | Evidence upload |
|------|----------------------|-----------------|
| Identity | name, email, password, phone, DOB, address (+ geocode), ABN, payment | Photo / photo ID — **post-register** (Credentials) |
| Screening | number, status, dates, state | Certificate — **post-register** |
| Qualifications | type, dates | Certificate — **post-register** |
| Checks | numbers, dates, state | PDF/image — **post-register** |
| Legal | terms + privacy versions | — |

---

## 10. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Large pre-auth form abandonment | Stepper saves nothing until submit; keep steps skippable except legal; clear progress indicator. |
| Geocode failures block register | Address optional; lookup failure allows manual entry without coords. |
| Removing staff create breaks ops habit | Invite-only is explicit product choice; document in release notes. |
| Duplicate code between register + profile steps | Extract shared step widgets + geocode helper module. |
| Invite `profile` jsonb orphaned | Stop writing from staff; optional future migration to drop column. |
| Payment/PII on register | Same encryption as Phase 2; no logging of account numbers. |

---

## 11. Key reference paths

**Frontend — remove / read-only**

- `lib/features/engagements/views/workforce_list_view.dart` — remove Add contractor
- `lib/features/engagements/views/contractor_onboarding_view.dart` — remove (after porting widgets)
- `lib/features/engagements/views/workforce_detail_view.dart` — read-only profile
- `lib/features/engagements/controllers/workforce_controller.dart` — remove `saveStaffProfile`

**Frontend — build / expand**

- `lib/features/contractor_register/` — stepper register
- `lib/features/compliance_ops/views/contractor_profile_ops_view.dart` — expanded edit
- `lib/features/clients/utils/site_geocode_apply.dart` — geocode apply
- `lib/core/constants/api_paths.dart` — `publicGeocode`

**Backend — modify / remove**

- `app/modules/contractors/router.py` — remove staff POST/PATCH; extend register
- `app/modules/contractors/service.py` — `register_contractor`
- `app/modules/contractors/staff_service.py` — keep get only
- `app/modules/contractors/schemas.py` — `ContractorRegisterRequest`

**Backend — keep**

- Engagements invite/list/resend, lifecycle, `awaiting_approval`
- `GET /v1/tenants/current/contractors/{id}` (read-only staff view)
- Credentials ACL (contractor upload, staff read)

**DB**

- No new migration required for pivot (V039–V041 already applied). Optional later: deprecate `invite_tokens.profile`.

---

## 12. Suggested implementation order

```
Phase A  Admin rollback (invite-only, read-only detail, remove staff create/patch APIs)
Phase B  Contractor register stepper + geocode on Identity
Phase C  Contractor profile expansion
Phase D  Cleanup, permissions, docs, regression
```

**Do not start Phase B until Phase A is approved.**  
**Do not start implementation until you give green light on this plan.**

---

## 13. Green light checklist

Please confirm or correct:

1. Phase order **A → B → C → D** OK?  
2. **Keep GET** staff contractor for read-only detail (remove POST/PATCH only)?  
3. Geocode on Identity — **lookup + confirm** pattern (not silent auto-fill without confirm)?  
4. Register stepper **step labels** OK: Identity → Screening → Qualifications → Checks → Legal & create account?  
5. Green light to proceed with **Phase A only** after you approve this document?
