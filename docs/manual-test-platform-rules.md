# Manual test guide — platform rules (full)

**Purpose:** Step-by-step manual QA for **all Flutter V1 platform rules** (staff + contractor), including compliance copy, shells, and dogfood fixes since `34dda14`.  
**Authoritative rules:** [2026-07-23-frontend-contractor-domain-restructure-design.md](./migration/2026-07-23-frontend-contractor-domain-restructure-design.md) (§4–§8)  
**Change overview:** [changes-summary-since-34dda14.md](./changes-summary-since-34dda14.md)  
**Slice QA (optional depth):** `docs/migration/manual-qa-s*.md`

Mark each checkbox as you go. Fail anything that crashes, shows blank screens, invents endpoints, or uses **forbidden** eligibility copy (§R).

---



## 0. Prerequisites



### 0.1 Backend

- API running (local or staging) with seed data.
- Demo staff: `admin@demotenant.example` / `ChangeMe123!` (or your seed).
- Legal docs seeded: `platform_terms` / `privacy_policy` versions match Flutter defines.
- Use a unique contractor email per full run (e.g. `contractor.qa+<stamp>@example.com`).



### 0.2 Flutter run

**Web (staff setup OK):**

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=DOMAIN_V2=true \
  --dart-define=TERMS_VERSION=v0.1-placeholder \
  --dart-define=PRIVACY_VERSION=v0.1-placeholder \
  --dart-define=BILLING_URL=https://example.com/billing
```

**Android emulator (contractor GPS / check-in):**

```bash
adb reverse tcp:8000 tcp:8000
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=DOMAIN_V2=true
```

See [local-emulator-api.md](./local-emulator-api.md).

### 0.3 Roles under test


| Actor                   | Shell                           | Typical needs                                      |
| ----------------------- | ------------------------------- | -------------------------------------------------- |
| Staff (`tenant_member`) | StaffShell `/staff/*`           | invite, approve, clients, jobs, visits, compliance |
| Contractor              | ContractorShell `/contractor/*` | onboarding, credentials, visits, schedule, profile |


**Rule:** Same user must **not** be both staff and contractor. Wrong shell → ActorGuard redirect + message.

---



## R. Non-negotiable compliance rules (spot-check anytime)

Fail the build if any of these are violated.


| ID  | Rule                    | Pass if                                                                                            |
| --- | ----------------------- | -------------------------------------------------------------------------------------------------- |
| R1  | Separate legal actions  | No single “I agree to everything”; Terms and Privacy accepted separately                           |
| R2  | Legal sequence          | Show markdown → `presented` → user Accept → `accepted` (notices → `acknowledged`)                  |
| R3  | Counsel-pending         | Unavailable message; no stale draft; cannot proceed without live accept                            |
| R4  | Metadata vs source      | Staff list is metadata by default; restricted evidence uses `/content` proxy when `proxy_required` |
| R5  | Scan states             | Show pending/clean/blocked; do not treat unscanned as approval-ready                               |
| R6  | Eligibility language    | Itemised reasons only; **never** “Verified by Rostiq”, “NDIS certified”, “Compliant worker”        |
| R7  | Sharing grant on accept | Named provider + `allow_source_evidence` toggle + withdrawal/end effects explained                 |
| R8  | MFA on review           | If API requires MFA for credential review, prompt — do not skip silently                           |
| R9  | Schedule copy           | Availability/leave are **preferences only** — do not imply they create visits                      |
| R10 | Web GPS                 | Check-in/complete disabled on web with mobile-app message                                          |
| R11 | Closed beta banner      | Interim privacy banner visible on staff and contractor shells                                      |


---



## 1. Gateway, login, shells



### 1.1 Gateway

- [x] Open app → **Gateway** (not admin/attendance role cards).
- [x] Links present: **Sign in**, **Register as contractor**, optional Provider signup (`LANDING_URL`) if configured.
- [x] Unauthenticated deep link to `/staff/*` or `/contractor/*` → redirected to gateway/login.



### 1.2 Staff login

- [x] Sign in as staff → lands **StaffShell** `/staff/home` (not contractor).
- [x] Login title is **role-neutral** (no “admin only” / wrong-role chrome).
- [x] Closed-beta privacy banner visible.
- [x] Nav items match permissions (Workforce / Clients / Jobs / Visits / Payments / Compliance / Settings). Missing perms → item hidden; deep-link → snackbar + home (not blank).
- [x] On phone: bottom **NavigationBar** works; destinations never empty.
- [x] Log out → gateway/login; tokens cleared.



### 1.3 Contractor login (active)

- [x] Active contractor → **ContractorShell** home (or soft docs banner if docs still needed).
- [x] Tabs: Home, Visits, Schedule, Credentials, Profile.
- [x] Onboarding routes stay **outside** tab chrome when funnel is required.



### 1.4 Guards & refresh

- [x] Staff token cannot open `/contractor/*` (and vice versa).
- [x] Web refresh with valid tokens restores session via `me/context` into correct shell.
- [x] Billing gate (402 / inactive subscription): modal + **Open billing** → `BILLING_URL`.

---



## 2. Contractor register & invite deep link



### 2.1 Public register (no invite)

- [x] Gateway → Register as contractor.
- [x] Form: full name, email, password; optional phone/dob.
- [x] Terms + Privacy accepted **separately** (bundled versions match `TERMS_VERSION` / `PRIVACY_VERSION`).
- [x] Submit → success → navigate to **login** (no tokens issued).
- [x] Rate-limit / validation errors show readable messages (no crash).



### 2.2 Staff invite → unregistered email

- [x] Staff → Workforce → **Invite** with new email + required categories (allowlist only).
- [x] Success shows **Registration email sent** (not only “Engagement created”) when API returns registration-invite union.
- [x] Invite without email+phone or empty categories → validation; no crash.
- [x] Inviting an **already registered** email → clear message: ask contractor to log in (`email_already_registered`).



### 2.3 Invite deep link register

- [ ] Open `/contractor/register?invite=<token>` (or emailed link).
- [ ] While invite loads: **Create account** disabled / submit no-ops.
- [ ] After load: email **pre-filled and read-only**; inviting tenant shown.
- [ ] Register with token → login → engagement appears for that tenant.
- [ ] Bad token / email mismatch → actionable error (`invite_token_invalid` / `invite_email_mismatch`).

---



## 3. Contractor onboarding funnel

**Entry rule:** Incomplete legal / invited engagement → force `/contractor/onboarding` **before** profile/tenant picker. Progress is **per contractor**.

### 3.1 Funnel chrome

- [x] No bottom-nav / rail during onboarding.
- [x] Progress steps visible; completed steps can be **skipped** on re-entry.
- [x] Continue blocked until current step’s N-of-M requirements met.
- [x] Async Accept/Continue shows spinner; double-tap does not double-submit.
- [x] UI does not dump raw `doc_key` chrome at users.



### 3.2 Legal (R1–R3)

- [ ] Fetches live `platform_terms` and `privacy_policy`.
- [ ] Each doc: markdown + version + separate Accept.
- [ ] Continue blocked until both accepted.
- [ ] Counsel-pending / missing permission → error; cannot fake-advance.



### 3.3 Collection notices

- [x] Notices listed; each acknowledged before Continue.
- [x] Cannot skip unread notices.



### 3.4 Sensitive consents

- [x] Consents for sensitive types before upload path (as product requires).
- [x] Checkbox / consent UI works; pending state independent of other actions.



### 3.5 Engagement accept (R7)

- [x] Invited engagement shows **named provider** + required categories.
- [x] Accept UI: metadata sharing explanation + `allow_source_evidence` toggle warning + withdrawal/end effects.
- [x] Confirm → accept succeeds; status moves off `invited` (e.g. `pending_docs`).
- [x] Continue blocked while any invite remains `invited`.
- [x] After accept: **switch-tenant** if needed and route to **home** (not stuck in credentials step).
- [x] `pending_docs` exits funnel; soft **docs-needed banner** on home with CTA to Credentials.



### 3.6 Re-login / multi-tenant

- [x] Incomplete platform onboarding still redirects into funnel on next login.
- [x] Progress restored for that contractor (not another profile’s progress).
- [x] Profile → switch tenant → lists refresh; no stale other-tenant data; `me/context` not stuck on single-flight cache.

---



## 4. Credentials & evidence



### 4.1 Contractor create (evidence required)

- [ ] Credentials → Create; type from **allowlist** only.
- [ ] Sensitive / government-ID types show extra consent / proxy behaviour as applicable.
- [ ] Wizard **requires evidence**; create without file → snackbar `evidence_required` (or equivalent).
- [ ] Upload shows **progress**; finalize binds document to `credential_id`.
- [ ] Scan states: pending / clean / blocked messaging (R5).
- [ ] List shows **status chips**; detail shows provenance / evidence presence.



### 4.2 View / download (R4)

- [ ] Contractor can view/download own evidence when permitted.
- [ ] Actions bound to correct `credential_id` (not wrong/sibling docs).
- [ ] Staff with grant + `credentials.source.read`: open evidence; if `proxy_required`, content proxy used (no fake “signed URL viewed”).



### 4.3 Staff review (R6, R8)

- [ ] Workforce detail → credentials / review without typing UUIDs (pickers).
- [ ] Decisions: accepted / rejected / re_review_required.
- [ ] MFA required → prompt shown; cannot silently skip.
- [ ] No forbidden eligibility copy anywhere on review/approve surfaces.



### 4.4 Sharing access request

- [ ] Staff can **request** credential share for an engagement/contractor path as implemented.
- [ ] Contractor can **approve** sharing access request.
- [ ] Alerts feed may show humanized “Access requested” (or similar) — no raw event codes as primary copy.

---



## 5. Workforce lifecycle (staff)



### 5.1 List & filters

- [x] Workforce list loads; status filters work (`invited`, `pending_docs`, `approved`, `active`, `suspended`, `ended`, etc.).
- [x] Human-friendly labels (not raw API enums as sole UI text where fixed).



### 5.2 Docs checklist on detail

- [x] Detail shows required vs missing credential categories.
- [x] Accepted credentials list visible when present.



### 5.3 Approve / activate (R6)

- [ ] Approve / Approve & activate when eligible.
- [ ] Incomplete → `eligibility_incomplete` with **itemised** reasons panel.
- [ ] Suspend / Resume / End honour `contractors.manage`.
- [ ] User **without** approve permission: lifecycle area explains empty state (not silent blank).

---



## 6. Clients CRM

- [x] Create client (name required).
- [x] Add site with address + **lat/lng** (required in Flutter).
- [x] Contacts CRUD.
- [x] Create client invite token; public `/invites/client/:token` (or `/invite/:token`) acknowledge works.
- [x] No NDIS client-pack / records-engine UI (out of V1 — must not invent).

---



## 7. Jobs, forms, recurrence



### 7.1 Job + form catalog

- [x] Create job with location XOR (`client_site_id` **or** `branch_id`).
- [x] Job detail: create/manage form catalog entries; refresh works.
- [x] Jobs list → form templates action opens templates UI.



### 7.2 Recurrence builder

- [x] Open recurrence rule builder from job.
- [x] Human-readable RRULE labels; preview shows **start–end** windows.
- [x] End at midnight coerced to **23:59** (no zero-length day).
- [x] Form chips use **job catalog only** (not unrelated tenant noise).
- [x] Generate visits → loading spinner; visits appear; Idempotency safe on retry.



### 7.3 Manual visit

- [x] Manual visit create includes catalog **form_requirements**.
- [x] Task title presets dropdown available where wired.

---



## 8. Visits (staff + contractor)



### 8.1 Staff board

- [x] Visits board filters (`from`/`to`/`job_id`) load rows.
- [x] Detail: reschedule via **day/time picker** (not +1h hack).
- [x] Cancel works when permitted.
- [x] Address/site labels preferred over geofence-only text where available.
- [x] No raw UUID fields for contractor/job assignment where pickers exist.



### 8.2 Contractor visit loop (mobile — R10)

- [x] Visits list shows upcoming; open scheduled visit.
- [x] Shows job/client, schedule window, status, tasks, required forms.
- [x] **Check in** with GPS → `checked_in` (or API equivalent).
- [x] Toggle tasks; submit required form / progress notes.
- [x] **Complete** with GPS → completed.
- [x] Failures map clearly: geofence rejected, forms incomplete, scan blocked, engagement not active.
- [x] On **web**: check-in/complete disabled with mobile location message.

---



## 9. Contractor schedule (R9)

- [x] Schedule tab: timetable / availability / leave.
- [x] Copy states preferences only — **does not create visits**.
- [x] Multi-window availability editor: add/edit multiple windows; save succeeds.
- [x] Leave in the past blocked in UI; API `leave_in_past` / overlap → readable snackbar.
- [x] Staff must not call contractor-me schedule APIs as staff.

---



## 10. Payments & rates

- [ ] Staff: engagement rate bands editor (`base`, `evening`, `night`, `saturday`, `sunday`, `public_holiday`).
- [ ] Payment batches: create / post / void; `band_breakdown` visible when API returns it.
- [ ] Contractor: payments via visits `payment_status` filter / profile link as implemented.
- [ ] Settings: timezone / `public_holiday_jurisdiction` when permitted.
- [ ] No employee payroll-period UX.

---



## 11. Compliance ops & notifications



### 11.1 Staff compliance

- [ ] Compliance section loads for users with any of: credentials.review, rights.manage, incidents.manage, audit.view.
- [ ] **Access history:** pick contractor by **name**, then credential; call requires `credential_id` on path `/v1/compliance/access-history` (not a wrong `/v1/access-history`).
- [ ] No eager fetch without credential selection.
- [ ] Rights queue / incidents create-open-close when permitted.
- [ ] Home alerts: humanized titles (not raw event type codes as primary text).



### 11.2 Contractor profile ops

- [ ] Rights request: access / correction / deletion / export.
- [ ] Privacy export.
- [ ] Consent withdraw with explanation dialog before withdraw.
- [ ] Docs-needed banner CTA → Credentials when `needsDocsAttention`.



### 11.3 Notifications

- [ ] Home alerts feed loads for both actors when events exist.
- [ ] Device register on login (non-fatal if Firebase unset); logout cleans token when applicable.

---



## 12. Permission matrix smoke (quick)

Hide or disable controls the JWT lacks. Spot-check with a reduced-permission staff role if available.


| Area                 | Need (any/all per design)             | Expected                      |
| -------------------- | ------------------------------------- | ----------------------------- |
| Workforce list       | `contractors.read`                    | Visible                       |
| Invite               | `contractors.invite`                  | Button works                  |
| Approve              | `contractors.approve`                 | Else explained empty / hidden |
| Activate/suspend/end | `contractors.manage`                  | Gated                         |
| Credential review    | `credentials.review`                  | Gated                         |
| Source evidence      | `credentials.source.read` + grant     | Else blocked                  |
| Clients              | `clients.read` / `clients.manage`     | Nav + CRUD                    |
| Jobs                 | `jobs.read` / `jobs.manage`           | Nav + mutate                  |
| Visits board         | `visits.read` / `visits.manage`       | Nav + mutate                  |
| Check-in / complete  | `visits.check_in` / `visits.complete` | Contractor mobile             |
| Rates / batches      | `payments.view` / `payments.manage`   | Payments                      |
| Access history       | `compliance.audit.view`               | Compliance                    |
| Incidents            | `compliance.incidents.manage`         | Compliance                    |
| Superuser            | `*` or `platform.admin`               | UI gates allow-all            |


---



## 13. End-to-end happy path (one run)

Use this as a single dogfood script covering the critical chain.

1. [ ] Staff login → invite **new** email with required categories.
2. [ ] Open invite register link → lock email → create account → login.
3. [ ] Complete onboarding: legal → notices → consents → accept (sharing grant) → exit to home.
4. [ ] Upload required credentials + evidence → scan clean.
5. [ ] Staff review credentials → approve engagement → activate.
6. [ ] Staff create client + site (lat/lng) → job + form → recurrence → generate visit.
7. [ ] Contractor (mobile): check in → tasks/forms → complete.
8. [ ] Staff: access history for a credential; contractor: privacy export / rights request smoke.
9. [ ] Log out both actors → gateway clean.

**Pass:** All steps succeed without crashes, blank screens, UUID-only inputs, or forbidden copy (R6).

---



## 14. Explicit out-of-scope (do not fail for missing)

- Records-engine / NDIS client packs (`/v1/records/*`)
- Company self-registration in Flutter / GoCardless checkout UI
- Retention / legal-hold admin UI / platform.admin console
- Visual rebrand
- Employee clock, PIN, old shift board, employee payroll periods

---



## Sign-off


| Field          | Value       |
| -------------- | ----------- |
| Tester         |             |
| Build / commit |             |
| API env        |             |
| Date           |             |
| Result         | Pass / Fail |
| Notes          |             |


---

*Prefer live API behaviour + the 2026-07-23 Flutter restructure design when docs conflict. Update this file when new platform rules ship.*