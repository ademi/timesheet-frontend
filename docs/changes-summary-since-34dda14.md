# Changes summary — since `34dda14`

**Base commit:** `34dda1407eb770a3c449abec3590fd02691f17dc`  
**Range:** ~62 commits through current `HEAD`  
**Scope:** Flutter contractor-domain frontend (dogfood + frustration fixes)

Short overview of what landed after that commit. Not a commit-by-commit log.

---

## Themes

### 1. Registration invite (Phase 0 / EUT W1)

- Staff invite can send a **registration invite** to an unregistered email (“Registration email sent”).
- Deep link `/contractor/register?invite=<token>` validates the invite, **locks email**, shows inviting tenant, and submits with `invite_token`.
- Clearer errors: invalid/mismatched invite, email already registered, email required for invite.

### 2. Onboarding funnel reliability (F1–F5, B1–B2)

- **Per-contractor** onboarding progress (saved and restored correctly).
- Incomplete platform onboarding routes **before** profile/tenant picker.
- Async buttons / pending-action UX so double-taps don’t break legal accept, notices, or consents.
- After engagement accept / `pending_docs`, funnel **exits to home** (not stuck on credentials).
- Skip already-completed steps; Continue uses an **N-of-M** gate; less raw `doc_key` chrome in the UI.

### 3. Engagement accept & workforce

- Better accept errors/copy and sharing-grant messaging.
- After accept: **switch-tenant** + land on contractor home.
- Docs-needed **banner on home** when credentials still required.
- Engagement **missing-categories checklist** + accepted docs list on workforce detail.
- Workforce **invite list filters**; empty lifecycle explained when approve permissions are missing.
- **Staff request credential share** + **contractor approve sharing request**.

### 4. Credentials & evidence (dogfood P2 / P5 / P6 / P8)

- Create wizard **requires evidence**; snackbar when `evidence_required`.
- Evidence **view/download** for contractor and staff, bound to `credential_id`.
- Upload **progress** indicator; **status chips** on credential list/detail.
- Staff/contractor flows no longer ask for raw UUIDs where pickers exist.

### 5. Jobs, recurrence & visits

- Recurrence **rule builder** UI + RRULE compiler + human-readable labels.
- Form catalog create/manage on job detail; manual visits send **form_requirements**.
- Midnight end window coerced to **23:59**; generate-visits **spinner**.
- Visit reschedule uses **day/time picker** (not “+1h”); task title **presets**.
- Prefer **address labels** over geofence-only display; jobs list wires form-templates action.

### 6. Contractor schedule

- **Multi-window** availability editor.
- Block **past leave** windows; map `leave_in_past` / overlap errors to readable messages.

### 7. Compliance, alerts & shells

- Access history: correct path, requires **credential_id**, contractor **name picker** (no eager UUID fetch).
- Documents list requires **owner_type + owner_id**.
- Humanized **home alerts** feed + notification display helpers.
- Closed-beta **privacy banner** on staff/contractor shells.
- Shell nav visible outside onboarding with real routes (stubs removed).
- Staff phone **NavigationBar** fixed; nav destinations never empty.
- Role-neutral **login** title; fewer duplicate login/onboarding fetches; safer `me/context` after switch-tenant.

### 8. Docs & tests

- New: `docs/local-emulator-api.md` (`adb reverse` + `127.0.0.1` for Android emulator).
- Spec copy under `docs/superpowers/specs/` (contractor domain restructure).
- SDD task reports under `.superpowers/sdd/`.
- Broad unit/widget coverage for onboarding, credentials, compliance, jobs, shell nav, etc.

---

## What this is *not*

- Not a full product redesign or rebrand.
- Records-engine, in-app billing checkout, and company self-registration remain out of Flutter V1.
- Employee clock / old shift board / employee payroll remain removed (contractor-domain product).

---

## Related reading

| Doc | Role |
|-----|------|
| [2026-07-23-frontend-contractor-domain-restructure-design.md](./migration/2026-07-23-frontend-contractor-domain-restructure-design.md) | Authoritative product / rules bible |
| [design-delta-2026-07-26.md](./migration/design-delta-2026-07-26.md) | What superseded older migration docs |
| [local-emulator-api.md](./local-emulator-api.md) | Emulator API wiring |
| [manual-test-platform-rules.md](./manual-test-platform-rules.md) | Full manual test guide for platform rules |
