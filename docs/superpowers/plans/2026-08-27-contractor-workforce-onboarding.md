# Contractor / Workforce Onboarding — Product & Engineering Plan

> **Status:** Phases 0–5 complete · ready for broader QA / release.  
> **Pivot (2026-08-30):** Phase 4 staff “Add contractor” stepper + staff CRM edit were **superseded** by contractor self-service register. Staff are **invite-only**; profile CRM editing is on contractor **Profile**; staff workforce detail Profile tab is **read-only**. See [2026-08-30-contractor-self-service-register.md](./2026-08-30-contractor-self-service-register.md).  
> **Rule:** Implement **one phase at a time**. After each phase, stop and wait for explicit approval before starting the next.  
> **Repos:** Frontend `timesheet-frontend` · Backend `…/flutter backend/timesheet/timesheet-backend` · DB `…/timesheet-db`

### Locked decisions (2026-08-27)

1. Phase order OK  
2. New status `awaiting_approval` — **yes** (Phase 3)  
3. Approve only from `awaiting_approval` — **yes**  
4. Keep both Approve and Approve & activate — **yes**  
5. Payment v1 = account name + BSB + account number — **yes**  
6. Staff create fields — **all optional**  
7. ABN — **not** via upsert `abn` credential; use a dedicated profile/form field (Phase 2)  
8. Proceed with **Phase 1**

**Goal:** Support two staff onboarding paths (full contractor create + light invite), richer contractor identity/compliance data, clearer invite/list/resend UX, improved signup (“complete your account”), and a clearer docs → approval lifecycle — without breaking existing engagement/credential flows.

---

## 1. Current state (summary)

| Area | Today |
|------|--------|
| Staff add contractor | **Invite only** (email/phone + required doc categories). No staff create profile API. |
| Invite UX | Preview dialog warns when email is **not** in Rostiq; staff can send email or link-only. |
| Workforce list | Engagements only (`invited` … `ended`). Pending **registration invites** are not listed as rows. |
| Resend invite | No dedicated resend; re-`POST` create supersedes pending token. No list “Re-email” button. |
| Contractor signup | Name, email, password, phone?, dob?, legal. **ABN is a credential**, not a form field. **No bank/payment details.** |
| After register | Funnel: Legal → Notices → Consents → Accept engagement. Docs uploaded later under Credentials. |
| Status after accept | `pending_docs` until staff **Approve** or **Approve & activate**. Status does **not** auto-change when uploads complete. |
| Staff detail | Lifecycle + rates + credentials review. **No** edit of identity/address/screening fields. |
| Client pattern to mirror | Horizontal stepper: Identity → Address → Preferences → Contacts → Representative → Funding → Legal (`client_onboarding_*`). |

---

## 2. Product decisions (proposed)

### 2.1 Two entry points, one destination

| Staff action | When | Result |
|--------------|------|--------|
| **Add contractor** | Staff has (or will enter) profile + compliance info | Create contractor + engagement draft → optional **Send invite** |
| **Invite contractor** | Fast path | Email (+ phone optional) + required categories → **always email** invite (and still return link as backup) |

Both land on the **same workforce detail** card where staff can view/edit info for **all** statuses.

### 2.2 Invite email behaviour (your updates)

- **Remove** the “Contractor not in Rostiq” warning / choose link-only dialog.
- **Always send** the invite email when inviting, whether the email is already registered as a contractor or not (existing engagement path still creates/re-notifies; registration path always emails).
- Keep copyable invite link on success as **backup**, not as a primary “don’t email” choice.
- **Re-email** available from list (and optionally detail) for pending invites / `invited` engagements.

### 2.3 Workforce list — invited emails

- List must show **pending registration invites** (email, Invited status, expiry) **and** existing engagements.
- Each invited / pending-invite row: status chip **Invited** + **Re-email** button.
- After the person registers/accepts, the invite row is replaced by the normal engagement row (same email).

### 2.4 Approve vs Approve & activate

**Keep both** — different operational intents:

| Action | Meaning | Use when |
|--------|---------|----------|
| **Approve** | Docs/eligibility OK → `approved`. Not yet assignable to live roster as active. | Compliance signed off; ops will activate later. |
| **Approve & activate** | Docs OK → jump straight to `active`. | Ready to work immediately. |

**UX copy (recommended):**

- Approve → “Approve documents”
- Approve & activate → “Approve and activate for work”

Secondary: on `approved`, keep standalone **Activate**.

### 2.5 Status when documents are uploaded

Today: stay on `pending_docs` until staff approves, even after all evidence is present.

**Proposed status model:**

```
invited
  → (contractor accepts / staff-created path reaches docs stage)
pending_docs          ← still missing required uploads
  → (all required evidence present)
awaiting_approval     ← NEW: waiting for staff document approval  ← “waiting for documents approval”
  → approve → approved → activate → active
  → (or approve-and-activate → active)
```

| Status | Label (UI) | Who acts |
|--------|------------|----------|
| `pending_docs` | Pending documents | Contractor (upload) |
| `awaiting_approval` | Waiting for document approval | Staff (review / approve) |

**Auto-transition rule:** when required categories all have usable evidence (same eligibility “missing” rules as today, evidence not `none`/`absent`/`quarantined`), engagement moves `pending_docs` → `awaiting_approval`. If a required doc is removed/superseded without replacement, move back to `pending_docs`.

Approve / approve-and-activate become valid from **`awaiting_approval`** (and optionally still from `pending_docs` only if staff overrides — **default: only from `awaiting_approval`** so staff don’t approve incomplete packs).

> Open for your confirmation: new DB status `awaiting_approval` vs renaming labels only. **Recommendation: new status** so filters and banners stay accurate.

### 2.6 ABN & payment on signup / complete account

- **ABN:** move off “required docs as the only place” onto the **main signup / complete-account form** as a normal field (still may store encrypted like today under credential type `abn`, or as profile field — see Phase B).
- **Payment details (optional):** BSB, account number, account name (and optionally PayID later). New storage needed (none today).
- **Complete your account:** post-register guided screen(s) for profile gaps: ABN, payment (optional), address if missing, then docs.

### 2.7 Staff “Add contractor” stepper (like client)

Horizontal stepper (same chrome as client onboarding). Proposed steps:

| # | Step | Purpose |
|---|------|---------|
| 0 | **Identity** | Name, DOB, contacts, residential address, photo + photo ID |
| 1 | **Screening** | NDIS Worker Screening Check |
| 2 | **Qualifications** | Certificates / training |
| 3 | **Checks** | WWCC, police check, licence, vehicle |
| 4 | **Invite** (optional last) | Required categories defaults + Send invite |

Finish may: save profile + engagement without invite, or save + send invite.

---

## 3. Field vs upload matrix (study result)

Convention:

- **Field** = typed / selected value staff or contractor enters  
- **Upload** = document evidence (PDF/image)  
- Most regulated items need **both** (identifier + dates + proof)

### Step 1 — Identity

| Information | Field | Upload | Notes |
|-------------|-------|--------|-------|
| Full name | ✅ required | — | |
| Date of birth | ✅ required | — | Age ≥ 16 (align register) |
| Email | ✅ required | — | Invite / login |
| Phone | ✅ recommended | — | |
| Residential address (line1, line2, suburb, state, postcode, country) | ✅ required | — | New storage (not on contractor today) |
| Profile photo | — | ✅ optional | Existing photo pipeline |
| Photo ID (passport **or** driver licence as identity) | Type + number + expiry (optional fields) | ✅ **required evidence** | Maps to existing `passport_id` / `drivers_licence` credentials |

### Step 2 — Screening (NDIS Worker Screening Check)

| Information | Field | Upload | Notes |
|-------------|-------|--------|-------|
| Screening check number | ✅ required | — | Store as credential identifier (`ndis_worker_screening`) |
| Clearance status | ✅ required (`cleared` / `excluded` / other) | — | New structured field on credential metadata or columns |
| Issue date | ✅ required | — | |
| Expiry date | ✅ required | — | Valid ~5 years; validate issue+5y default |
| State/territory of issue | ✅ required | — | AU states/territories enum |
| Certificate / outcome letter | — | ✅ required | Evidence on same credential |

### Step 3 — Qualifications

Each qualification = one credential-like row (type + dates + file).

| Item | Field | Upload | Credential type (existing / new) |
|------|-------|--------|----------------------------------|
| Cert III/IV Individual Support / Disability / Aged Care | Type/name, issue date, expiry? | ✅ certificate | `cert_iii` (+ subtypes in metadata or new types) |
| Nursing / allied health degree | Name/level, issue date | ✅ | `nursing_bachelor`, `nursing_diploma`, `other_health_qualification` |
| First Aid / CPR (HLTAID011) | Issue + expiry | ✅ | `first_aid`, `cpr` |
| Medication administration | Issue + expiry | ✅ | **new** e.g. `medication_admin` |
| Epilepsy management | Issue + expiry | ✅ | **new** e.g. `epilepsy_management` |
| Manual handling | Issue + expiry | ✅ | **new** e.g. `manual_handling` |

Staff stepper: add **0..N** qualification rows (not all mandatory at create). Tenant policy / required categories still decides what is mandatory for **approve**.

### Step 4 — Checks

| Item | Field | Upload | Type |
|------|-------|--------|------|
| Working With Children Check | Number, state, expiry | ✅ | `wwcc` |
| National police check | Issue date (age policy already ≤365d) | ✅ | `police_check` |
| Driver’s licence | Number, state, class?, expiry | ✅ | `drivers_licence` (shared with photo ID — one record can serve both if type matches) |
| Vehicle registration | Plate, state, expiry | ✅ optional | **new** e.g. `vehicle_registration` |
| Vehicle insurance | Insurer, policy #, expiry | ✅ optional | **new** or fold into `insurance` with subtype |

**Screening vs police check:** keep eligibility alternative (`police_check` ↔ `ndis_worker_screening`) unless product wants both always.

### Signup / Complete account extras

| Item | Field | Upload |
|------|-------|--------|
| ABN | ✅ (11-digit validate) | Optional supporting doc |
| Payment — account name | ✅ optional | — |
| Payment — BSB | ✅ optional | — |
| Payment — account number | ✅ optional | — |

---

## 4. Architecture sketch

```
Staff: Add contractor (stepper)
  → POST create contractor profile (+ address, optional creds metadata)
  → create engagement (status: invited or pending_docs — decide in Phase C)
  → optional send invite email

Staff: Invite (light)
  → always email; list shows pending invites; re-email endpoint

Contractor: Register / Complete account
  → identity basics + ABN + optional payment
  → upload remaining required docs
  → pending_docs → awaiting_approval when complete

Staff: Detail
  → view/edit all domains for every contractor
  → review docs → Approve | Approve & activate
```

**Repos ownership**

| Layer | Path |
|-------|------|
| API | `…/timesheet/timesheet-backend` |
| Migrations / seeds | `…/timesheet/timesheet-db` |
| Flutter UI | `timesheet-frontend` |

---

## 5. Phased delivery

Each phase: **backend + db (if needed) → frontend → smoke test → STOP for green light.**

---

### Phase 0 — Align & lock decisions

**No product code.** Confirm with you:

1. New status `awaiting_approval` — **yes/no**?
2. Approve only from `awaiting_approval` — **yes/no**?
3. Payment details: store encrypted at rest (recommended) — **yes/no**?
4. Staff create: create **user+contractor without password** (invite sets password later) vs require invite before login — **recommended: draft contractor/engagement; login only after register/accept invite**.
5. Stepper credentials: staff uploads evidence on behalf of contractor at create — **yes** (assumed)?
6. Exact mandatory fields at staff create vs optional-until-approve.

**Exit:** This plan updated with answers; then Phase 1 green light.

---

### Phase 1 — Invite UX: always email, list invites, re-email

**Why first:** Smallest high-value change; unblocks ops; little schema risk.

**Backend / DB**

- [x] Always send invite notification on create (registration **and** existing contractor), ignore “link only” as primary path; keep `invite_url` in response.
- [x] Soft-deprecate or ignore `send_email: false` for staff invites (or force `true`).
- [x] `GET /v1/tenants/current/contractor-invites` lists pending registration invites.
- [x] `POST …/contractor-invites/{id}/resend` and `POST …/engagements/{id}/resend-invite`.
- [x] Existing-contractor invite payload includes `contact_email` and emails via notification pipeline.
- [x] Preview copy updated (no link-only wording).

**Frontend**

- [x] Remove invite warning dialog (“not in Rostiq” / Link only / Send email).
- [x] Invite submit always requests email send.
- [x] Workforce list: show invited emails with **Invited** + **Re-email**.
- [x] Success dialog: keep link as backup only.

**Out of scope this phase:** stepper, ABN, payment, new statuses.

**Green light gate:** Invite always emails; list shows pending invites; re-email works. **← waiting for your OK before Phase 2.**

---

### Phase 2 — Signup: ABN + optional payment + “Complete your account”

**Backend / DB**

- [x] ABN on register / `PATCH /v1/contractor-me` as profile field (`workforce.contractors.abn`) — not credential upsert.
- [x] `workforce.contractor_payment_details` with encrypted account number (Fernet reuse).
- [x] `PUT/DELETE /v1/contractor-me/payment-details`; payment nested on `ContractorOut`.
- [x] ABN excluded from credential category catalog used by invite chips.
- [x] Migration `V039__contractor_abn_and_payment.sql` in `timesheet-db`.

**Frontend**

- [x] Register form: optional ABN + optional payment fields.
- [x] Complete your account screen (`/contractor/complete-account`) + post-login redirect when ABN missing.
- [x] Home banner + Profile business details editor.
- [x] ABN removed from invite required-doc allowlist / catalog.

**Green light gate:** New contractor can set ABN + optional bank details without using credentials UI for ABN. **← waiting for your OK before Phase 3.**

---

### Phase 3 — Docs uploaded → `awaiting_approval` + approve UX

**Backend / DB**

- [x] Migration: add `awaiting_approval` to engagement status CHECK (`V040`).
- [x] Hook on credential create/supersede/evidence/scan + required-docs update: sync `pending_docs` ↔ `awaiting_approval`.
- [x] Approve / approve-and-activate only from `awaiting_approval`.
- [x] Staff notification event `engagement.awaiting_approval`.
- [x] Lifecycle tests updated for 409 from `pending_docs`.

**Frontend**

- [x] New status chip/filter label: “Waiting for document approval”.
- [x] Overview actions on `awaiting_approval`: “Approve documents” / “Approve and activate for work”.
- [x] Contractor home banners: upload remaining vs waiting for approval.

**Green light gate:** Completing uploads flips status; approve paths work; filters correct.

---

### Phase 4 — Staff Add contractor (horizontal stepper) + detail edit

> **Superseded (2026-08-30):** Staff create/patch APIs and Add contractor UI were removed. Contractors fill profile via the **register stepper** and **Profile** screen; staff see read-only Profile on workforce detail. [Pivot plan →](./2026-08-30-contractor-self-service-register.md)

**Backend / DB**

- [x] Staff create contractor API (profile + address + optional structured screening/qual/check payloads).
- [x] Address (+ screening structured fields) on contractor or related tables / credential metadata.
- [x] New credential types as needed (`medication_admin`, `epilepsy_management`, `manual_handling`, `vehicle_registration`, …).
- [x] Collection notices seeds for new types.
- [x] Staff PATCH profile/compliance on engagement detail for **all** contractors.
- [x] Optional: create engagement in `invited` or `pending_docs` and attach required categories.
- [x] Wire “Send invite” after create.
- [x] Migration `V041__contractor_address_and_invite_profile.sql` (address columns + invite `profile` jsonb).
- [x] Invite fulfill applies staff profile draft onto contractor.

**Frontend**

- [x] `ContractorOnboardingView` mirroring client horizontal stepper (Identity → Screening → Qualifications → Checks → Invite).
- [x] FAB: **Add contractor** + keep **Invite**.
- [x] Workforce detail: view/edit same domains for every contractor.
- [x] Reuse client onboarding chrome patterns (`step` + step labels + Next/Back).

**Out of scope this phase:** staff upload-on-behalf of credential evidence (ACL remains contractor-owned).

**Green light gate:** Staff can create full contractor, invite from stepper, and edit info on detail for invited/active/etc.

---

### Phase 5 — Polish, permissions, audit, docs

- [x] Permissions: `contractors.invite` (light invite/resend) vs `contractors.manage` (create/edit profile) — manage already existed in seeds; create/patch + UI now gated on manage.
- [x] Audit events for staff-entered PII / payment changes (`contractor_staff_invite_created`, `contractor_staff_created`, `contractor_profile_updated`, `contractor_payment_upserted` / `_deleted`) — field names / flags only, no raw PII.
- [x] Empty states, validation messages, mobile layout for stepper.
- [x] Update internal docs / seed demos (plan, manual-test matrix, seed-v2 README).
- [x] Regression anchors: permission/audit tests in `tests/contractors/test_staff_create_permissions.py`; existing lifecycle / registration invite / NDIS smoke remain the invite→approve path.

**Green light gate:** Ready for broader QA / release.

---

## 6. Suggested implementation order (reminder)

```
Phase 0  decisions
Phase 1  invite list/resend          ← done
Phase 2  ABN + payment + complete account  ← done
Phase 3  awaiting_approval status    ← done
Phase 4  staff stepper + detail edit ← done
Phase 5  polish                      ← done
```

Do **not** start Phase N+1 until you say go after Phase N.

---

## 7. Risks & dependencies

| Risk | Mitigation |
|------|------------|
| Staff-created contractor without auth user | Clear invite/register path before login; don’t orphan engagements. |
| Duplicate identity: photo ID vs driver’s licence | One credential record; stepper maps carefully. |
| Payment data sensitivity | Encrypt; restrict read permissions; never log raw account numbers. |
| Eligibility engine vs new status | Update `evaluate_engagement_eligibility` + lifecycle tests together. |
| Large stepper scope | Phase 4 can ship Identity+Screening first, Quals/Checks as 4b if needed. |

---

## 8. What I need from you (green light checklist)

Please confirm or correct:

1. **Phase order** OK as above?  
2. **New status** `awaiting_approval` (“Waiting for document approval”) — approve?  
3. **Approve** only when status is `awaiting_approval`?  
4. **Keep both** Approve and Approve & activate with clearer labels?  
5. **Payment fields:** account name + BSB + account number enough for v1?  
6. **Staff stepper mandatory set** at create: which of Identity fields are required before Save? (Recommendation: name, DOB, email, address, photo ID upload; screening required if they support NDIS participants; quals/checks optional until required-categories say otherwise.)  
7. **ABN:** store as profile field, or auto-create `abn` credential from the form? (Recommendation: form field that upserts `abn` credential so eligibility/sharing stay consistent.)  
8. Green light to proceed with **Phase 0 answers → then Phase 1 only**?

---

## 9. Key reference paths

**Frontend**

- `lib/features/engagements/views/workforce_list_view.dart`
- `lib/features/engagements/views/workforce_invite_view.dart`
- `lib/features/engagements/views/workforce_detail_view.dart`
- `lib/features/contractor_register/`
- `lib/features/clients/views/client_onboarding_view.dart` (stepper pattern)

**Backend**

- `app/modules/engagements/` (invite, lifecycle)
- `app/modules/contractors/` (register, me)
- `app/modules/credentials/` (types, eligibility)

**DB**

- `migrations/V003` engagements/contractors  
- `migrations/V012` credentials  
- `migrations/V015` invite tokens  
- `seed-v2/` for notices / demos
