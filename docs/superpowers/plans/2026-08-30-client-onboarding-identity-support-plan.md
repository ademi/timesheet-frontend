# Client onboarding — Identity, Contacts & Support Plan refresh

> **Status:** Phase G complete · ready for QA / release.  
> **Rule:** Implement **one phase at a time**. After each phase, stop and wait for explicit approval before starting the next.  
> **Repos:** Frontend `timesheet-frontend` · Backend `…/flutter backend/timesheet/timesheet-backend` · DB `…/timesheet/timesheet-db`

---

## 1. Goal

Update the **Add client** 7-step onboarding wizard so that:

1. **Identity** focuses on participant demographics + **card document attachments** (Medicare, Companion, Disability, Pension) and **no longer collects NDIS**.
2. **Contacts** becomes **fully optional** (no mandatory emergency contact).
3. **Funding** is renamed and restructured as **Support Plan**, with NDIS number + plan PDF at the top, expanded plan-manager / support-coordinator details, and new optional allied-health professional sections (Behavioural, Speech, Occupational, Physiotherapy).

**Out of scope (unchanged in this plan unless noted):** Address, Preferences, Representative, Legal steps; `participant_support_plans.body_json` clinical care plan; public client invites; readiness hard-gates beyond new requirement seeds.

---

## 2. Current state (as of 2026-08-30)

### 2.1 Wizard structure

| Step | Label | Key files |
|------|-------|-----------|
| 0 | Identity | `onboarding_identity_step.dart`, `client_onboarding_controller.dart` |
| 1 | Address | `onboarding_address_step.dart` |
| 2 | Preferences | `onboarding_preferences_step.dart` |
| 3 | Contacts | `onboarding_contacts_step.dart` |
| 4 | Representative | `onboarding_representative_step.dart` |
| 5 | Funding | `onboarding_funding_step.dart` |
| 6 | Legal | `onboarding_legal_pack_step.dart` |

Shell: `client_onboarding_view.dart` · Keys: `onboarding_keys.dart` · Care-plan parity store: `support_plan_funding_consent_store.dart`

### 2.2 Identity — today

| Field | UI | Persisted | Required |
|-------|-----|-----------|----------|
| Profile photo | Yes | `PUT …/profile-photo` + `client_photo` doc | No |
| Full name | Yes | `POST/PATCH /v1/clients` | Yes |
| Email | Yes | client row | Email **or** phone |
| Phone | Yes | client row | Email **or** phone |
| Date of birth | Yes | client row + fact `dob` | Yes |
| **NDIS number** | Yes | fact `ndis` | **Yes** |
| Medicare | Text only | fact `medicare_card` (value only) | No |
| Referred by | Dropdown + Other | fact `referral_source` | Other text if Other |
| Sex / gender | Dropdown + Other | fact `sex_gender` | No |
| ATSI status | Dropdown | fact `atsi_status` | No |
| Allergies | Textarea | fact `allergies` | No |

**Gap vs requirements:** No card **attachments** for Medicare / Companion / Disability / Pension. NDIS is on Identity (should move to Support Plan). Labels say “Full name” / “Sex / gender” (requirements say “Participant …”).

Backend already supports **dual capture** (`field` + `document`) for `medicare_card` and `ndis` (`V020__client_types_and_requirements.sql`). No requirement keys exist yet for companion, disability, or pension cards.

### 2.3 Contacts — today

Sub-flow: **emergency (required)** → optional carer → optional more contacts.

- `submitContacts()` blocks Next until `hasEmergencyContact` is true (`client_onboarding_controller.dart`).
- Backend does **not** enforce emergency contact on create; validation is **frontend-only**.

### 2.4 Funding — today

Step title: **Funding**. Persisted via `PUT /v1/clients/{id}/profile/{requirement_key}`.

| Section | Fields (requirement keys) | Required |
|---------|---------------------------|----------|
| Plan management | `plan_management_type` | Yes |
| Plan manager (if plan_managed) | `plan_manager_name`, `plan_manager_phone`, `plan_manager_email` | Name + phone **or** email |
| Plan dates | `plan_start_date`, `plan_end_date` | No |
| Budgets | `budget_core`, `budget_cb`, `budget_capital` | No |
| Cap | `funding_not_to_exceed` | No |
| Support coordinator | `support_coordinator_name/phone/email` | No |

**Gap vs requirements:** No NDIS number / NDIS PDF on this step. Plan manager lacks company, ACN/ABN, org ID, address. Support coordinator lacks company, ACN/ABN, org ID, address. No therapist sections. Label “Funding not to exceed” should become **Other** (see §4 decisions).

Care-plan **Funding + Consent** tab (`SupportPlanFundingConsentStore`) mirrors the same keys — must stay in sync after changes.

---

## 3. Target state (new requirements)

### 3.1 Identity step

| Field | Capture |
|-------|---------|
| Participant full name | Text (client row) |
| Participant gender | Select (+ Other free text, existing pattern) |
| Participant date of birth | Date |
| Participant phone number | Text |
| Participant email | Text |
| Participant Medicare | **Document attachment** (+ optional number, dual capture) |
| Participant Companion card | **Document attachment** |
| Participant Disability card | **Document attachment** |
| Participant Pension card | **Document attachment** |

**Remove from Identity:** NDIS number (moves to Support Plan).

**Open product choice:** Keep or drop Referral, ATSI, Allergies, profile photo on Identity? (Not mentioned in new requirements — default: **keep** unless you say remove.)

### 3.2 Contacts step

- Entire step **optional** — user may skip without adding any contact.
- If user adds a contact, existing field-level validation remains (relationship, phone or email, etc.).
- Add **Skip contacts** (or allow Next with empty step) similar to **Skip nominee** on Representative.

### 3.3 Support Plan step (renamed from Funding)

**Header / first block**

| Field | Capture |
|-------|---------|
| NDIS number | Text |
| NDIS PDF plan | Document attachment |
| Other | Free text (replaces “Funding not to exceed”) |

**Existing blocks (retain unless you say remove):** plan management type, plan dates, core/CB/capital budgets.

**Plan manager details** (required when plan management = plan_managed)

| Field |
|-------|
| Plan manager name |
| Company name |
| ACN/ABN |
| Organisation ID |
| Phone number |
| Email |
| Address |

**Support coordinator** (optional)

| Field |
|-------|
| SC name |
| Company name |
| ACN/ABN |
| Organisation ID |
| Phone number |
| Email |
| Address |

**Behavioural therapists** (optional) — same 7-field shape as SC, label “Specialist name” instead of “SC name”.

**Speech therapists** (optional) — same shape.

**Occupational therapists** (optional) — same shape.

**Physiotherapist** (optional) — same shape.

---

## 4. Phase 0 — Decisions to lock before coding

| # | Question | Recommendation | Your call |
|---|----------|----------------|-----------|
| D1 | Identity: email **and** phone both required, or keep email-or-phone? | Keep **email or phone** (less breaking) | ✅ **Both required** |
| D2 | Identity card uploads: **document-only** or number + attachment (Medicare)? | Medicare: **dual** (matches backend); Companion/Disability/Pension: **document-only** | ⏳ *Using recommendation unless you say otherwise* |
| D3 | Are card attachments **required** or optional? | **Optional** (soft), unless compliance says otherwise | ✅ **Optional** |
| D4 | NDIS number: still **tenant-unique** when moved to Support Plan? | **Yes** — keep `ndis_normalized` uniqueness in `profile_service` | ⏳ *Using recommendation unless you say otherwise* |
| D5 | “Other” replacing `funding_not_to_exceed`: free-text **notes** field? | Rename key to `support_plan_other` (text), migrate existing numeric facts optionally | ✅ **Yes — free-text Other** |
| D6 | Therapist sections: **one row each** or allow multiple? | **One row per discipline** for v1 (matches SC pattern) | ✅ **Option A — one per type** |
| D7 | Plan manager address: single line or structured (line1/city/state/postcode)? | **Single textarea** for v1; geocode not required | ⏳ *Using recommendation unless you say otherwise* |
| D8 | Keep Referral / ATSI / Allergies / photo on Identity? | **Keep** (not in new spec) | ✅ **Yes — keep all** |
| D9 | Rename step label only (“Support Plan”) or also route/readiness copy? | **UI label + step indicator**; internal step index unchanged | ⏳ *Using recommendation unless you say otherwise* |
| D10 | Deprecate `funding_not_to_exceed` or alias to new “Other” key? | New key + **read fallback** from old key in hydrate | ⏳ *Using recommendation unless you say otherwise* |

### Locked (2026-08-30)

- **D1:** Participant **email and phone are both required** on Identity (validation change from today’s email-or-phone rule).
- **D3:** Card attachments (Medicare, Companion, Disability, Pension) are **optional**.
- **D5:** Replace “Funding not to exceed” with a free-text **Other** field (`support_plan_other`).
- **D6:** **One therapist per discipline** (Behavioural, Speech, Occupational, Physiotherapy) — single 7-field block each, same as Support coordinator.
- **D8:** Keep profile photo, Referral, ATSI, and Allergies on Identity.

**Phase 0 complete.** D2/D4/D7/D9/D10 use plan recommendations (Medicare dual capture, NDIS tenant-unique, single-line address, UI label rename, new Other key with legacy fallback).

**Ready for Phase A** — reply with green light to start the DB migration.

---

## 5. Proposed data model (DB migration V042+)

All new fields follow the existing **`clients.client_type_requirements`** + **`client_profile_facts`** pattern (no new tables).

### 5.1 Identity — new / updated requirements

| requirement_key | label | capture_modes | value_type | document_category |
|-----------------|-------|---------------|------------|-------------------|
| `medicare_card` | *(existing)* | field, document | text | `medicare_card` |
| `companion_card` | Companion card | document | — | `companion_card` |
| `disability_card` | Disability card | document | — | `disability_card` |
| `pension_card` | Pension card | document | — | `pension_card` |

> Note: `concession_card` exists in V020 as a generic concession field — **do not reuse** for pension if product wants a distinct pension card upload; add `pension_card` as above.

### 5.2 Support Plan — new / updated requirements

**NDIS (move semantic ownership to Support Plan UI; key unchanged)**

| requirement_key | notes |
|-----------------|-------|
| `ndis` | Already dual field+document; UI moves to Support Plan step |

**Replace funding cap**

| requirement_key | label | value_type |
|-----------------|-------|------------|
| `support_plan_other` | Other | text |
| `funding_not_to_exceed` | *(deprecated)* | keep for back-compat read |

**Plan manager expansion**

| requirement_key | label |
|-----------------|-------|
| `plan_manager_name` | *(existing)* |
| `plan_manager_company` | Company name |
| `plan_manager_abn_acn` | ACN/ABN |
| `plan_manager_org_id` | Organisation ID |
| `plan_manager_phone` | *(existing)* |
| `plan_manager_email` | *(existing)* |
| `plan_manager_address` | Address |

**Support coordinator expansion**

| requirement_key | label |
|-----------------|-------|
| `support_coordinator_name` | *(existing)* |
| `support_coordinator_company` | Company name |
| `support_coordinator_abn_acn` | ACN/ABN |
| `support_coordinator_org_id` | Organisation ID |
| `support_coordinator_phone` | *(existing)* |
| `support_coordinator_email` | *(existing)* |
| `support_coordinator_address` | Address |

**Allied health (optional, one block each)**

Prefix pattern `{discipline}_*` where discipline ∈ `behavioural_therapist`, `speech_therapist`, `occupational_therapist`, `physiotherapist`:

`suffix` ∈ `name`, `company`, `abn_acn`, `org_id`, `phone`, `email`, `address`

Example: `speech_therapist_name`, `speech_therapist_company`, …

**Document categories to add:** `companion_card`, `disability_card`, `pension_card` (NDIS PDF continues to use category `ndis`).

Update `OnboardingKeys.carePlanOwnedFundingKeys` and backend requirement sort_order so Support Plan fields group logically (200–299 band).

---

## 6. Implementation phases

### Phase A — Database & requirement catalog

**Why first:** Frontend and backend profile upserts depend on seeded requirement keys.

**Deliverables (`timesheet-db`)**

- [x] New migration `V042__client_onboarding_identity_support_plan.sql`:
  - Insert new `client_type_requirements` rows for `patient` platform type (pattern from `V033`).
  - Add document categories in `field_schema_json.accept` where applicable.
  - Seed `support_plan_other`; mark `funding_not_to_exceed` label deprecated for back-compat.
- [x] Verify sort_order grouping: Identity cards 61–63, Support Plan NDIS 195, plan manager 201–207, SC 230–236, therapists 250–286.

**Backend**

- [x] No schema change to tables beyond migration seeds (facts table already flexible).
- [x] Confirm `documents/service.py` allows PDF + images for new categories (default whitelist already includes pdf/jpeg/png/webp).
- [x] Test: `tests/clients/test_client_onboarding_v042_requirements.py` asserts all V042 keys seeded.

**Green light gate:** Migration applies cleanly; `GET /v1/clients/types/{patient_id}/requirements` lists all new keys. **← apply V042 on your DB, then run the test above.**

---

### Phase B — Backend profile & validation touch-ups

**Why second:** Ensure upsert, readiness, and NDIS uniqueness work with relocated NDIS and new keys.

**Deliverables (`timesheet-backend`)**

- [x] `profile_service.py`: verified `ndis` uniqueness runs on Support Plan upsert (no code change — keyed on `requirement_key`).
- [x] `evaluate_readiness`: V042 requirements default `soft` / not required — confirmed not blocked.
- [x] Tests:
  - `tests/clients/test_client_onboarding_v042_requirements.py` — seed assertions
  - `tests/clients/test_client_onboarding_v042_profile_facts.py` — upsert all text keys, card documents, category mismatch, plan manager bundle, deferred NDIS, readiness, requirements API

**Green light gate:** Backend test suite passes; manual API upsert of sample Support Plan bundle succeeds. ✅ (46 tests passed)

---

### Phase C — Frontend Identity step

**Why third:** Decouples participant identity from NDIS; adds card uploads.

**Deliverables (`timesheet-frontend`)**

- [x] `onboarding_identity_step.dart`:
  - Update labels to “Participant …” where specified.
  - Remove NDIS number field.
  - Add document pickers for Medicare, Companion, Disability, Pension (reuse upload pattern from Legal / client detail — `DocumentPipeline.uploadEvidence` + `ProfileFactUpsert`).
- [x] `client_onboarding_controller.dart`:
  - Remove NDIS from `submitIdentity()` validation and fact upserts.
  - Add upload state + submit handlers for four card types.
  - Hydrate document status on resume from profile bundle if available.
- [x] `onboarding_keys.dart`: add `companionCard`, `disabilityCard`, `pensionCard` constants.
- [x] New widgets/models: `onboarding_identity_card_field.dart`, `identity_card_attachment.dart`.
- [x] Tests: `client_onboarding_controller_test.dart`, `onboarding_identity_other_test.dart`, adult/child flow tests — updated Identity assertions (no NDIS on step 0).

**Green light gate:** Create client through Identity with card uploads; client row created without NDIS; resume shows attached docs. ✅

---

### Phase D — Frontend Contacts optional

**Why fourth:** Small, isolated behaviour change.

**Deliverables**

- [x] `client_onboarding_controller.dart`: `submitContacts()` allows Next with zero contacts; removed emergency required error.
- [x] `client_onboarding_view.dart`: **Skip contacts** footer button when no contacts saved (`showSkipContacts`).
- [x] `onboarding_contacts_step.dart`: helper copy that contacts are optional.
- [x] Tests: skip/advance with no contacts, non-emergency-only contact, view smoke for Skip contacts footer.

**Green light gate:** User completes onboarding with zero contacts; existing add-contact flow still works. ✅

---

### Phase E — Frontend Support Plan step (rename + expand)

**Why fifth:** Largest UI/controller change; depends on Phase A keys and Phase C NDIS removal.

**Deliverables**

- [x] Rename step label **Funding → Support Plan** in `client_onboarding_view.dart` step indicator and `onboarding_support_plan_step.dart` (replaced `onboarding_funding_step.dart`).
- [x] Top section: NDIS number (required) + NDIS PDF upload + **Other** text field.
- [x] Expand plan manager + support coordinator sections (7 fields each).
- [x] Add four collapsible optional sections for therapists (shared widget `SupportPlanProfessionalSection` + `SupportPlanProfessionalFields`).
- [x] `client_onboarding_controller.dart`: move NDIS validation/upload from Identity to `submitSupportPlan()`; upsert all new keys; rename `fundingNotToExceedCtrl` → `supportPlanOtherCtrl`.
- [x] `onboarding_keys.dart`: add all new constants; update `carePlanOwnedFundingKeys`.
- [x] Tests: funding/support plan validation, plan_managed required fields, NDIS duplicate error on this step.

**Green light gate:** Full wizard run with NDIS only on Support Plan; all professional sections optional; plan_managed validates expanded plan manager fields. ✅

---

### Phase F — Care plan & client detail parity

**Why sixth:** Staff edit Support Plan outside onboarding via care plan UI.

**Deliverables**

- [x] `support_plan_funding_consent_store.dart` + funding UI section: mirror all Phase E fields (hydrate + save + conflict handling).
- [x] Client detail overview/profile tabs if they surface NDIS, medicare, or funding fields (`clients_controller.dart`, detail widgets).
- [x] Read fallback: display `funding_not_to_exceed` in Other if `support_plan_other` empty (legacy clients).

**Green light gate:** Edit Support Plan on existing client matches onboarding fields; legacy data displays correctly. ✅

---

### Phase G — Docs, QA matrix & regression

**Deliverables**

- [x] Update `docs/flutter-client-types-add-client-guide.md` (or add onboarding addendum).
- [x] Manual QA checklist (see §8).
- [x] Full regression: create → skip contacts → Support Plan → Legal finish; resume incomplete onboarding; NDIS collision; document permission denied paths.

**Green light gate:** Ready for QA / release. ✅

---

## 7. API flow after changes

No new endpoints. Same incremental pattern:

```
Step 0 Identity
  POST /v1/clients  (no NDIS)
  PUT  …/profile/medicare_card      { value_json?, document_id? }
  PUT  …/profile/companion_card     { document_id }
  PUT  …/profile/disability_card    { document_id }
  PUT  …/profile/pension_card       { document_id }
  … existing sex_gender, dob, etc.

Step 3 Contacts
  (optional) POST …/contacts

Step 5 Support Plan
  PUT  …/profile/ndis               { value_json, document_id? }
  PUT  …/profile/support_plan_other   { value_json }
  PUT  …/profile/plan_management_type …
  PUT  …/profile/plan_manager_* …
  PUT  …/profile/support_coordinator_* …
  PUT  …/profile/behavioural_therapist_* …
  … etc.
```

Document upload pipeline unchanged: `POST /v1/documents/upload-url` → PUT content → finalize → link via profile fact.

---

## 8. Manual QA checklist (Phase G)

- [ ] Identity: all four card types upload (PDF + image).
- [ ] Identity: client created without NDIS.
- [ ] Contacts: Skip / Next with no contacts succeeds.
- [ ] Contacts: emergency + carer still savable when provided.
- [ ] Support Plan: NDIS required; duplicate NDIS shows field error.
- [ ] Support Plan: NDIS PDF attaches under category `ndis`.
- [ ] Support Plan: plan_managed requires plan manager name (+ contact channel).
- [ ] Support Plan: each therapist block optional; partial fill saves only filled keys.
- [ ] Support Plan: “Other” text saves; old clients with `funding_not_to_exceed` still display.
- [ ] Resume onboarding: Identity + Support Plan hydrate correctly.
- [ ] Care plan Funding tab matches onboarding Support Plan fields.
- [ ] User without `documents.upload` sees clear error on upload steps.

---

## 9. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| NDIS moved off Identity breaks “create client early” uniqueness check | Run NDIS upsert + uniqueness on Support Plan Next; client row created without NDIS is valid |
| 28+ new requirement keys clutter catalog | Group sort_order; shared UI widget for 7-field professional blocks |
| `SupportPlanFundingConsentStore` drift | Phase F explicitly mirrors Phase E; shared key list in `OnboardingKeys` |
| Legacy `funding_not_to_exceed` numeric data | Hydrate fallback to Other display; optional one-time backfill migration later |
| Large Support Plan step UX | Collapsible sections; optional disciplines collapsed by default |
| Document-only requirements reject value-only upserts | Use `document_id`-only upserts; backend CHECK allows document-only facts |

---

## 10. Key reference paths

### Frontend

| Area | Path |
|------|------|
| Wizard shell | `lib/features/clients/views/client_onboarding_view.dart` |
| Controller | `lib/features/clients/controllers/client_onboarding_controller.dart` |
| Identity step | `lib/features/clients/widgets/onboarding/onboarding_identity_step.dart` |
| Funding step | `lib/features/clients/widgets/onboarding/onboarding_funding_step.dart` |
| Contacts step | `lib/features/clients/widgets/onboarding/onboarding_contacts_step.dart` |
| Profile keys | `lib/features/clients/utils/onboarding_keys.dart` |
| Care plan funding | `lib/features/clients/controllers/support_plan_funding_consent_store.dart` |
| Upload helper | `lib/features/clients/services/client_legal_upload_helper.dart` |
| Tests | `test/features/clients/client_onboarding_*.dart` |

### Backend

| Area | Path |
|------|------|
| Client router | `app/modules/clients/router.py` |
| Profile service | `app/modules/clients/profile_service.py` |
| Onboarding tests | `tests/clients/test_client_onboarding_v1.py` |
| Documents | `app/modules/documents/service.py` |

### Database

| Area | Path |
|------|------|
| Base client schema | `migrations/V004__clients_and_docs.sql` |
| Patient requirements seed | `migrations/V020__client_types_and_requirements.sql` |
| Funding/onboarding seed | `migrations/V033__client_onboarding_v1.sql` |
| **New migration (planned)** | `migrations/V042__client_onboarding_identity_support_plan.sql` |

---

## 11. Before vs after summary

| Area | Today | After |
|------|-------|-------|
| Identity NDIS | Required on step 0 | **Removed** |
| Identity cards | Medicare text only | Medicare + Companion + Disability + Pension **attachments** |
| Contacts | Emergency required | **Fully optional** |
| Step 5 title | Funding | **Support Plan** |
| Step 5 NDIS | Not on step | **NDIS number + PDF** at top |
| Funding cap | `funding_not_to_exceed` (number) | **Other** (text) |
| Plan manager | Name, phone, email | **+ company, ACN/ABN, org ID, address** |
| Support coordinator | Name, phone, email | **+ company, ACN/ABN, org ID, address** |
| Therapists | None | **4 optional 7-field blocks** |

---

**Next step:** Review §4 decisions (D1–D10). Reply with green light for **Phase A** (or note any decision changes) and implementation will begin.
