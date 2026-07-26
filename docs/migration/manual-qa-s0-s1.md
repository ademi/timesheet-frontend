# Manual QA — S0 Skeleton + S1 Contractor register

**App:** Flutter (`timesheet-frontend`)  
**API:** `http://localhost:8000` (branch `contractor_workflow`)  
**Slices:** S0 (shells, session, gateway) · S1 (public contractor register)

Use this checklist for a full manual pass. Check each box as you go.

---

## 0. Prerequisites

### Backend

1. API running and healthy:
  - Open `http://localhost:8000/ready` → expect ready/OK.
  - OpenAPI: `http://localhost:8000/docs`.
2. DB seeds applied (at least):
  - `001_dev_seed.sql` (roles / permissions)
  - `002_demo_tenant_users.sql` (staff demo users)
  - `011_compliance_policy_placeholders.sql` (legal versions for register)
3. If register still returns **500**, restart the API after the fix documented in [backend-handoff-contractor-register-nested-txn.md](./backend-handoff-contractor-register-nested-txn.md).



### Flutter

From the frontend root:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=BILLING_URL=https://rostiq.co/billing \
  --dart-define=LANDING_URL=https://rostiq.co/signup \
  --dart-define=TERMS_VERSION=v0.1-placeholder \
  --dart-define=PRIVACY_VERSION=v0.1-placeholder \
  --dart-define=DOMAIN_V2=true
```

**Important:** `TERMS_VERSION` / `PRIVACY_VERSION` must match DB current versions for `platform_terms` / `privacy_policy` (local seed = `v0.1-placeholder`).

### Accounts you will use


| Role                        | How you get it                                           | Email                           | Password                   |
| --------------------------- | -------------------------------------------------------- | ------------------------------- | -------------------------- |
| **Staff** (`tenant_member`) | Demo seed `002_demo_tenant_users.sql`                    | `admin@demotenant.example`      | `ChangeMe123!`             |
| Staff (alt)                 | Same seed                                                | `supervisor@demotenant.example` | `ChangeMe123!`             |
| **Contractor**              | Create in S1 register (no seed contractor for this pass) | *you choose a new email*        | *you choose* (rules below) |


**Password rules (register / API):** min 8 chars, at least one uppercase, one lowercase, one digit. Example: `Contractor1!`

**Do not** try to register with a staff email (e.g. `admin@demotenant.example`) — backend returns hard-split / conflict.

Optional demo tenant id (only if login UI/API ever asks for it):  
`a0000001-0001-4001-8001-000000000001`

---



## S0 — Skeleton (gateway, login, shells, logout, refresh)



### S0-1 Gateway (no role cards)

- [ ] Cold start opens **Gateway** (or resumes session — see S0-6).
- [ ] Gateway shows **three** actions only:
  - Sign in
  - Register as contractor
  - Provider signup
- [ ] **No** “Admin Panel” / “Attendance” role cards.
- [ ] **Sign in** → `/login`.
- [ ] **Register as contractor** → `/contractor/register`.
- [ ] **Provider signup** opens external `LANDING_URL` (browser / new tab). If it fails, snackbar should show the URL.



### S0-2 Staff login → StaffShell

- [ ] On Login, enter:
  - Email/phone: `admin@demotenant.example`
  - Password: `ChangeMe123!`
- [ ] Submit → lands on `/staff/home` (Staff home stub).
- [ ] Staff nav visible (rail on wide web): Home, and other items only if JWT permissions allow (Workforce, Clients, Jobs, Visits, Payments, Compliance, Settings).
- [ ] Switching a visible staff nav item changes route under `/staff/...` and keeps the shell chrome.

**If login fails:** confirm seed `002` was applied; confirm API is the contractor_workflow process; check Network tab for `POST /v1/auth/login` and `GET /v1/auth/me/context`.

### S0-3 Logout → Gateway

- [ ] From Staff home (or any shell stub), tap the **logout** icon in the app bar (top-right).
- [ ] After logout, app shows **Gateway** (not legacy admin/attendance portal).
- [ ] Tokens cleared — opening a `/staff/...` URL redirects to Gateway.



### S0-4 Contractor path after register (ties to S1)

Complete **S1** first so you have a contractor account, then:

- [ ] Login with the contractor email/password you registered.
- [ ] Lands on `/contractor/home` *or* `/contractor/onboarding` (onboarding if no/invited/pending engagements — expected for a brand-new contractor).
- [ ] Contractor shell (bottom nav on narrow / rail on wide): Home, Visits, Schedule, Credentials, Profile.
- [ ] Onboarding route (if shown) has **no** tab chrome.



### S0-5 Wrong actor (optional)

- [ ] While logged in as staff, manually navigate to `/contractor/home` → **Wrong actor** (or redirect away from contractor shell).
- [ ] While logged in as contractor, manually navigate to `/staff/home` → **Wrong actor**.



### S0-6 Web refresh keeps session

- [ ] Log in as staff → `/staff/home`.
- [ ] Refresh the browser (F5).
- [ ] Still authenticated; stay on staff shell (or restore via gateway resume into staff home).
- [ ] Repeat with contractor after S1.



### S0 pass criteria


| Check                                                             | Pass? |
| ----------------------------------------------------------------- | ----- |
| Gateway has Sign in / Register / Provider signup only             |       |
| Staff login → `/staff/home`                                       |       |
| Contractor login → `/contractor/home` or `/contractor/onboarding` |       |
| Logout → Gateway                                                  |       |
| Web refresh keeps session                                         |       |


---



## S1 — Contractor register

Use a **new** email each run (e.g. `contractor.qa+<timestamp>@example.com`).

### S1-1 Open register from Gateway

- [ ] Gateway → **Register as contractor**.
- [ ] Screen title / form for public register (not a stub “coming soon”).



### S1-2 Form fields

Fill:


| Field     | Required | Example                        |
| --------- | -------- | ------------------------------ |
| Full name | Yes      | `QA Contractor`                |
| Email     | Yes      | `contractor.qa+s1@example.com` |
| Password  | Yes      | `Contractor1!`                 |
| Phone     | No       | `+61412345678` or `0412345678` |
| DOB       | No       | pick via date picker           |


- [ ] Validation: empty name/email/password blocked.
- [ ] Weak password (e.g. `password`) blocked with clear message (uppercase/lowercase/digit / length).



### S1-3 Legal accept (separate)

- [ ] **Platform Terms** block shows markdown + `doc_key: platform_terms` + version (`v0.1-placeholder` unless you overrode defines).
- [ ] **Privacy Policy** block shows markdown + `doc_key: privacy_policy` + version.
- [ ] Two **separate** checkboxes; cannot submit with only one checked.
- [ ] Submit with neither checked → error snackbar.



### S1-4 Successful register → login

- [ ] Accept both → **Create account**.
- [ ] Success snackbar (account created / sign in).
- [ ] Navigates to **Login** (no tokens / not dropped into shell).
- [ ] Optional Network check: `POST /v1/contractors/register` → **201** with `contractor_id`, `user_id`, `email` only (no `access_token`).



### S1-5 Login with new contractor

- [ ] On Login, use the email/password from S1-4.
- [ ] Lands on `/contractor/home` or `/contractor/onboarding`.



### S1-6 Negative cases

- [ ] Register again with **same email** → error (conflict / already registered), stay on register or show snackbar.
- [ ] Register with staff email `admin@demotenant.example` → hard-split / conflict style error.
- [ ] Link **Already have an account? Sign in** → Login.



### S1 pass criteria


| Check                                  | Pass? |
| -------------------------------------- | ----- |
| Register form + separate Terms/Privacy |       |
| 201 register → Login (no auto shell)   |       |
| New contractor can log in              |       |
| Duplicate / hard-split errors shown    |       |


---



## Quick API smoke (optional, before UI)

```bash
# Health
curl http://localhost:8000/ready

# Staff login
curl -X POST http://localhost:8000/v1/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"admin@demotenant.example\",\"password\":\"ChangeMe123!\"}"

# Register (use a unique email)
curl -X POST http://localhost:8000/v1/contractors/register ^
  -H "Content-Type: application/json" ^
  -d "{\"full_name\":\"QA Contractor\",\"email\":\"contractor.qa+api@example.com\",\"password\":\"Contractor1!\",\"terms_version\":\"v0.1-placeholder\",\"privacy_version\":\"v0.1-placeholder\"}"
```

If register returns **500**, stop UI testing for S1 and follow [backend-handoff-contractor-register-nested-txn.md](./backend-handoff-contractor-register-nested-txn.md).

---



## Known gaps (do not fail S0/S1 for these)

- Staff/Contractor **home content** is stubs (real widgets land in later slices).
- Provider signup is external only (no in-app company register).
- Legal markdown is **bundled**; after login, S2 will re-fetch live compliance docs.
- Demo `employee*` users are **not** the contractor path for this QA.
- Stub screens include an app-bar **logout** icon for S0 dogfood.

---



## Results log (fill in)


| Date | Tester | S0          | S1          | Notes / blockers |
| ---- | ------ | ----------- | ----------- | ---------------- |
|      |        | Pass / Fail | Pass / Fail |                  |


