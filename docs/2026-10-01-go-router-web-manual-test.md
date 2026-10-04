# Manual test guide — `go_router` on web (GetX on mobile)

**Date:** 2026-10-01  
**Scope:** Verify Path B from `[2026-09-27-go-router-web-only-plan.md](./2026-09-27-go-router-web-only-plan.md)` (Phases 0–6) and §F in `[2026-09-22-ux-friction-inventory.md](./2026-09-22-ux-friction-inventory.md)`.  
**ADR:** `[adr-go-router-web-only.md](./adr-go-router-web-only.md)`

**What you are proving**


| Platform                       | Router                               | Must prove                                                              |
| ------------------------------ | ------------------------------------ | ----------------------------------------------------------------------- |
| **Chrome (primary)**           | `GetMaterialApp.router` + `GoRouter` | Refresh / back / forward / paste URL / deep links keep the right screen |
| **iOS / Android (regression)** | `GetMaterialApp` + GetX `GetPage`    | Login, shells, list → detail still work; app does **not** boot GoRouter |


Tick every checkbox. On fail, note: **case id**, URL in address bar, expected, actual, screenshot.

---



## 0. Setup



### 0.1 Accounts


| Role                                                         | Use for                               |
| ------------------------------------------------------------ | ------------------------------------- |
| **Staff admin** (`tenant_member`)                            | C1–C6, C8, shell tabs, clients/visits |
| **Contractor** (approved engagement)                         | C7 wrong-actor, M2 contractor shell   |
| Optional: staff user **without** a permission you care about | Permission-denied redirect (optional) |




### 0.2 Seed data (create once before web tests)

1. At least **one client** with a known id (open Clients → open detail → copy `id=` from the URL).
2. A client that can enter **onboarding** (or resume an existing onboarding).
3. At least **one visit** and ideally **one shift** you can open from Roster/Visits (copy `id=` from URL after open).
4. Optional: a **billing export** id, **workforce** member id, **public client invite token** from email/API.

Write them here before you start:


| Entity                         | Id / token |
| ------------------------------ | ---------- |
| Client id                      |            |
| Visit id                       |            |
| Shift id                       |            |
| Public invite token (optional) |            |




### 0.3 Run Flutter Web (Chrome)

From the frontend repo root (adjust `API_BASE_URL` to your API):

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Or your usual staging defines (`TERMS_VERSION`, `PRIVACY_VERSION`, etc.).

**Pass criteria for boot**

- [ ] App opens in Chrome (not a blank page).
- [ ] Address bar uses **path URLs** (e.g. `http://localhost:xxxxx/gateway` or `/login`) — **not** hash URLs like `/#/gateway`.
- [ ] You land on **Gateway** or **Login** when logged out.



### 0.4 How to record each case

For every case below:

1. Do the steps in order.
2. Check the **address bar** after each important action.
3. Tick Pass or write Fail notes under the case.
4. Prefer Incognito / a clean profile when testing logged-out paste (avoids sticky cookies).

---



## Part A — Chrome (go_router)

> Complete Part A fully. This is the main acceptance suite for the update.



### Prep A — Log in as staff and capture deep URLs

> **If the address bar stays on** `/staff/clients` **(or** `/staff/visits`**) with no** `?id=` **after opening a detail:** do a **full restart** of the web app (`R` in the Flutter tool, or stop + `flutter run` again). Detail screens use `AppNavigator.push`; web requires `GoRouter.optionURLReflectsImperativeAPIs = true` in `main.dart` so the browser URL shows path + query. Hot reload alone may not pick that up.

1. Open the app in Chrome.
2. Log in as **staff admin**.
3. Confirm you reach **Staff home** (`/staff/home` or equivalent post-login home).
  - [x] Pass
4. Navigate: **Clients** → open your seeded client.
  - Address bar should look like: `/staff/clients/detail?id=<CLIENT_ID>`
  - [x] URL path is `/staff/clients/detail` (not still `/staff/clients`)
  - [x] URL has `?id=<CLIENT_ID>`
  - Copy the full URL → paste into the seed table above.
5. From client detail, open **Onboarding** (or start onboarding).
  - Address bar should include `/staff/clients/onboarding` and `id=` (and often `step=`).
  - [x] URL has `id` (and `step` if the wizard exposes it)
  - Advance **one step** in the wizard so `step` changes if applicable.
  - Copy the full URL.
6. Navigate: **Visits / Roster** → open a visit.
  - Expected: `/staff/visits/detail?id=<VISIT_ID>`
  - [x] URL path is `/staff/visits/detail` (not still `/staff/visits`)
  - [x] URL has `?id=`
7. From that visit (or roster), open a **shift detail** if available.
  - Expected: `/staff/visits/shift-detail?id=<SHIFT_ID>` (or with visit id query — accept whatever the app writes, but it must be shareable).
  - [x] URL identifies the shift

---



### C1 — Refresh mid-flow keeps URL and hydrates

**Goal:** F5 refresh must **not** dump you on home or an empty screen.

#### C1.1 Client onboarding

1. While logged in, go to the **onboarding URL** you copied (or Clients → client → Onboarding → move to a mid step).
2. Confirm the URL shows `id=` and the current step (if used).
3. Press **Chrome Refresh** (F5 / Ctrl+R).
4. Wait for the app to finish loading (no permanent spinner forever).

**Expected**

- [x] Address bar **still** shows the same path + query (`id`, `step` unchanged or restored).
- [x] You are **not** sent to `/staff/home` or `/gateway`.
- [x] Onboarding UI loads for **that client** (name/id match).
- [x] If `step=` was present, the **same step** (or equivalent content) is shown — not always step 0 unless product resets intentionally.

**Fail notes:** _______________________________________________

#### C1.2 Visit detail

1. Go to `/staff/visits/detail?id=<VISIT_ID>` (from seed table).
2. Confirm visit content loads.
3. Press **Refresh**.

**Expected**

- [x] URL unchanged (`id` still present).
- [x] Same visit loads (not empty / not “select a visit”).
- [x] Not redirected to home.

**Fail notes:** _______________________________________________

#### C1.3 Shift detail

1. Go to your shift detail URL with id.
2. Press **Refresh**.

**Expected**

- [x] URL kept; shift content loads for that id.
- [x] Not redirected to home.

**Fail notes:** _______________________________________________

---



### C2 — Chrome Back / Forward after navigation (and after refresh)

**Goal:** Browser history matches in-app destinations.

#### C2.1 Tab / list history

1. From staff home, click **Clients** in the shell.
2. Click **Visits**.
3. Click **Clients** again.
4. Press **Chrome Back** once.

**Expected**

- [x] You return to **Visits** (or the previous shell tab).
- [x] Address bar matches that tab (`/staff/visits` or `/staff/clients`).
- [x] Shell highlight matches the URL.

1. Press **Chrome Forward** once.

**Expected**

- [x] You return to **Clients**.
- [x] URL and shell highlight match.

**Fail notes:** _______________________________________________

#### C2.2 Detail → back after refresh

1. Open **Clients** → open a client detail (`/staff/clients/detail?id=…`).
2. Press **Refresh**.
3. Use the in-app **AppBackButton** (leading back), **not** Chrome Back first.

**Expected**

- [x] Back control is **visible** after refresh (does not disappear).
- [x] Tapping it returns to a sensible parent (usually clients list `/staff/clients`), not a blank route.

1. Open client detail again, then press **Chrome Back**.

**Expected**

- [x] Leaves detail for the previous history entry (often clients list).
- [x] No logout / gateway bounce.

**Fail notes:** _______________________________________________

#### C2.3 Forward after leaving a detail

1. From clients list → open detail → Chrome Back to list → Chrome Forward.

**Expected**

- [x] Detail reappears with the **same** `?id=`.
- [x] Client data loads again.

**Fail notes:** _______________________________________________

---



### C3 — Paste protected URL (logged out vs logged in)



#### C3.1 Logged out → protected URL

1. Log out (or open **Incognito** with no session).
2. Confirm you are on `/gateway` or `/login`.
3. In the address bar, paste a protected URL, e.g.
  `http://<host>/staff/clients/detail?id=<CLIENT_ID>`  
   Press Enter.

**Expected**

- [x] You are **not** shown the client detail content while logged out.
- [x] You land on **gateway** and/or **login** (auth redirect).
- [x] After successful login, either you resume toward the deep link **or** land on post-login home — record which; both are acceptable if documented. Prefer: deep link restored if product supports it.

**Actual after login:** _______________________________________

**Fail notes:** _______________________________________________

#### C3.2 Logged in → paste protected URL

1. Log in as staff.
2. Paste the same client detail URL into the address bar → Enter.

**Expected**

- [x] Client detail for that `id` loads without going through gateway steal.
- [x] URL stays `/staff/clients/detail?id=…`.

**Fail notes:** _______________________________________________

---



### C4 — Open deep URL in a new tab (same session)

1. Stay logged in as staff in Tab A.
2. Copy a deep URL (client detail or visit detail).
3. Open **New Tab** (Tab B) → paste URL → Enter.

**Expected**

- [x] Tab B loads the same entity (same id) without forcing re-login (same browser session/cookies).
- [x] Tab A is unaffected.
- [x] Refresh in Tab B still keeps the deep URL.

**Fail notes:** _______________________________________________

---



### C5 — Logout mid-flow and session expiry



#### C5.1 Explicit logout mid-flow

1. Open onboarding or visit detail mid-flow.
2. Use the app **Logout** (settings / profile / menu — wherever staff logout lives).

**Expected**

- [ ] You leave the deep screen.
- [ ] Land on **gateway** or **login**.
- [ ] Address bar is **not** still the protected deep path with private content visible.
- [ ] Pasting the old deep URL while logged out behaves like C3.1.

**Fail notes:** _______________________________________________

#### C5.2 Auth interceptor / 401 → login (optional but important)

**How to provoke (pick one):**

- Wait until access token expires (if short-lived in your env), then trigger an API call (pull-to-refresh / navigate), **or**
- In DevTools → Application → clear / corrupt the access token in secure storage equivalent if your build exposes it, **or**
- Temporarily stop the API so calls fail in a way that triggers 401 handling (only if your interceptor maps that to logout — prefer real 401).

**Expected**

- [ ] App navigates to **login** via `AppNavigator` (no stuck spinner on a deep route with “unauthorized” forever).
- [ ] User can log in again.

**Skip?** [ ] N/A this run — reason: ___________________________

**Fail notes:** _______________________________________________

---



### C6 — Must-change-password → first-login

**Prerequisite:** A user whose JWT / session has `must_change_password` (or your seed “first login” staff).

1. Log out.
2. Log in as that user.

**Expected**

- [x] You are sent to `/first-login` (not staff home).
- [x] Completing password change then proceeds to normal post-login home.
- [x] Pasting `/staff/home` while still must-change should bounce back to first-login (if still flagged).

**Skip?** [ ] N/A — no such account in this environment.

**Fail notes:** _______________________________________________

---



### C7 — Contractor opening `/staff/...` → wrong-actor

1. Log out of staff.
2. Log in as **contractor**.
3. Confirm contractor shell (`/contractor/home` or similar).
4. In the address bar, paste `/staff/home` or `/staff/clients` → Enter.

**Expected**

- [x] You do **not** see staff clients/home content.
- [x] You land on `/wrong-actor` (or equivalent wrong-actor screen).
- [x] UI explains wrong account type / offers path back to login or contractor home.

**Fail notes:** _______________________________________________

---



### C8 — Unknown path → Page not found

1. Log in as staff.
2. Paste a nonsense path, e.g.
  `http://<host>/staff/this-route-does-not-exist` → Enter.

**Expected**

- [x] Screen title/copy: **“Page not found”** (or equivalent).
- [x] Shows the unknown path somewhere on the page.
- [x] Button **“Go to home”** is visible.

1. Click **Go to home**.

**Expected**

- [x] Unknown page dismisses.
- [x] You land on post-login home (e.g. `/staff/home`) — not stuck on 404.

1. (Optional) Open DevTools Console: look for a log like
  `[go_router] unknown route path=... authenticated=true`

**Expected**

- [x] Log appears in debug builds.

1. Log out → paste the same unknown path.

**Expected**

- [x] Unauthenticated users are redirected toward **gateway/login** (not a confusing authenticated 404 with staff CTAs). Record actual behavior: _______________

**Fail notes:** _______________________________________________

---



### C9 — Public client invite while logged out

**Prerequisite:** A valid invite token (email link or API). If none, mark N/A.

1. Log out / Incognito.
2. Open:
  `http://<host>/invites/client/<TOKEN>`  
   (also try legacy `/invite/<TOKEN>` if your emails still use it).

**Expected**

- [x] Public invite UI loads **without** requiring staff login first.
- [x] Not redirected forever to gateway in a loop.
- [x] Invalid token shows a clear error (if you can test a fake token).

**Skip?** [ ] N/A — no token.

**Fail notes:** _______________________________________________

---



### C10 — Shell tabs + URL sync (extra)

1. Log in as staff.
2. Click each primary shell destination you have: Home, Visits, Clients, Workforce, Payments, Billing, Settings (and others if shown).

For each:

- [x] URL path matches the tab (e.g. Clients → `/staff/clients`).
- [x] Content matches the tab.
- [x] Refresh on that tab **stays** on that tab (not home steal).

**Fail notes:** _______________________________________________

---



### C11 — Onboarding step in URL (extra)

1. Open client onboarding.
2. Move forward **one step** using Next.
3. Watch the address bar.

**Expected**

- [x] `step=` (or equivalent) updates when the step changes, **or** step is otherwise restorable after refresh (document which).

1. Refresh.
2. Confirm you remain on the same logical step.

**Fail notes:** _______________________________________________

---



### C12 — Billing export detail / workforce detail (spot check)

1. Open Billing exports → open one export detail if available.
  Expected shape: `/staff/billing/exports/detail?id=…` (and `tab=` if used).
2. Refresh.

- [x] Same export loads.

1. Open Workforce → member detail `?id=…` → Refresh.

- [x] Same member loads.

**Skip sections you have no data for.**

**Fail notes:** _______________________________________________

---



## Part B — iOS / Android regression (GetX, no go_router)

> Prove mobile was **not** broken by the web-only router. Use emulator or device.



### B0. Run mobile

```bash
# Android example (adjust API)
adb reverse tcp:8000 tcp:8000
flutter run -d <device_id> --dart-define=API_BASE_URL=http://127.0.0.1:8000
```



### M1 — Login / logout / gateway resume

1. Cold-start the app logged out → gateway/login works.
2. Log in as staff → land on staff home.
3. Force-kill the app and relaunch while session is still valid.

**Expected**

- [ ] Session resumes to a sensible home (staff/contractor).
- [ ] App does not crash on resume.

1. Log out → back to gateway/login.

- [ ] Pass

**Fail notes:** _______________________________________________

### M2 — Staff + contractor shells / primary tabs

1. As staff, tap through main tabs (Home, Clients, Visits, etc.).
2. Log out; log in as contractor; tap contractor tabs (Home, Visits, Schedule, Credentials, Profile).

**Expected**

- [ ] No blank shells / no web-only 404 pages.
- [ ] Tabs switch content correctly.

**Fail notes:** _______________________________________________

### M3 — Clients list → detail → onboarding (GetX stack)

1. Staff → Clients → open client → open Onboarding.
2. Use Android/iOS **system back** and/or in-app back.

**Expected**

- [ ] Stack pops as before (detail ← onboarding, list ← detail).
- [ ] No crash; onboarding still usable.

**Fail notes:** _______________________________________________

### M4 — Visits → visit/shift detail; AppBackButton

1. Open Visits → visit detail → (optional) shift detail.
2. Use **AppBackButton**.

**Expected**

- [ ] Pops to parent screen.
- [ ] Visit/shift content loaded from navigation args/params as before.

**Fail notes:** _______________________________________________

### M5 — Confirm mobile is not on GoRouter bootstrap

**Dev-only checks (any one is enough):**

- [ ] In debug, you do **not** see continuous `[go_router]` route logs on every tab change the way Chrome does with `debugLogDiagnostics`.
- [ ] Or: code path — mobile uses `GetMaterialApp` + `getPages` (not `MaterialApp.router` / `createAppGoRouter`) — confirm via known behavior: **there is no browser address bar**; deep “paste URL” cases from Part A do not apply.
- [ ] Unknown nonsense route via in-app navigation still fails gracefully under GetX (no web `UnknownRoutePage` required on mobile).

**Fail notes:** _______________________________________________

---



## Part C — Results summary


| Case                           | Pass / Fail / Skip | Tester | Date |
| ------------------------------ | ------------------ | ------ | ---- |
| C1.1 Onboarding refresh        |                    |        |      |
| C1.2 Visit refresh             |                    |        |      |
| C1.3 Shift refresh             |                    |        |      |
| C2.1 Tab back/forward          |                    |        |      |
| C2.2 Detail back after refresh |                    |        |      |
| C2.3 Forward to detail         |                    |        |      |
| C3.1 Paste logged out          |                    |        |      |
| C3.2 Paste logged in           |                    |        |      |
| C4 New tab deep link           |                    |        |      |
| C5.1 Logout mid-flow           |                    |        |      |
| C5.2 401 → login               |                    |        |      |
| C6 First-login                 |                    |        |      |
| C7 Wrong-actor                 |                    |        |      |
| C8 Unknown route               |                    |        |      |
| C9 Public invite               |                    |        |      |
| C10 Shell tabs                 |                    |        |      |
| C11 Onboarding step URL        |                    |        |      |
| C12 Billing/workforce spot     |                    |        |      |
| M1 Login/logout/resume         |                    |        |      |
| M2 Shells                      |                    |        |      |
| M3 Clients stack               |                    |        |      |
| M4 Visits back                 |                    |        |      |
| M5 No go_router on mobile      |                    |        |      |




### Sign-off

- **Environment (API / build):** _________________________________
- **Chrome version:** _________________________________
- **Mobile device/OS:** _________________________________
- **Overall:** [ ] Accept  [ ] Accept with follow-ups  [ ] Reject
- **Follow-ups:** _______________________________________________

---



## Quick reference — important paths


| Screen                | Typical path                          |
| --------------------- | ------------------------------------- |
| Gateway               | `/gateway`                            |
| Login                 | `/login`                              |
| First login           | `/first-login`                        |
| Wrong actor           | `/wrong-actor`                        |
| Staff home            | `/staff/home`                         |
| Clients               | `/staff/clients`                      |
| Client detail         | `/staff/clients/detail?id=`           |
| Client onboarding     | `/staff/clients/onboarding?id=&step=` |
| Visits                | `/staff/visits`                       |
| Visit detail          | `/staff/visits/detail?id=`            |
| Shift detail          | `/staff/visits/shift-detail?id=`      |
| Support compose       | `/staff/support/compose`              |
| Billing exports       | `/staff/billing/exports`              |
| Billing export detail | `/staff/billing/exports/detail?id=`   |
| Contractor home       | `/contractor/home`                    |
| Public invite         | `/invites/client/:token`              |
| Legacy invite         | `/invite/:token`                      |


---



## Related docs

- Plan + matrices: `[2026-09-27-go-router-web-only-plan.md](./2026-09-27-go-router-web-only-plan.md)` §Phase 6.4 / 6.5  
- ADR: `[adr-go-router-web-only.md](./adr-go-router-web-only.md)`  
- Superseded GetX-web notes: `[web-refresh-back-button-fix.md](./web-refresh-back-button-fix.md)`  
- GetX lifecycle vs GoRouter: `[2026-10-04-getx-controller-lifecycle-gorouter.md](./2026-10-04-getx-controller-lifecycle-gorouter.md)`

---

## Controller freshness (leave → re-enter)

**Why:** GoRouter `onEnter` bindings do not dispose GetX controllers. After Phases 0–3 of the lifecycle plan, Tier-3 screens use `putFresh` (or onboarding `onExit` release) and shell tabs use `putOrReenter` + `onScreenReenter()`.

**Pass =** leave the screen, change something elsewhere (or open another entity), come back → UI is clean or shows the **current** route entity — not the previous draft/id.

### F1. Tier-3 entity / wizard (must recreate)

| # | Flow | Steps | Pass |
|---|------|-------|------|
| F1.1 | Support plan | Open support plan for client A → edit a field → back → open for client B | [ ] Shows B (not A’s draft) |
| F1.2 | Client onboarding | Start/resume client A → advance a step → leave (back to list) → open client B onboarding | [ ] Shows B; step URL sync within one client still works |
| F1.3 | Group shift edit | Edit shift A → leave → open edit for shift B | [ ] Shift B fields |
| F1.4 | Group shift book | Start book wizard → leave mid-flow → open book again | [ ] Starts on People (not stale Review) |
| F1.5 | SIL house detail | Open house A → leave → open house B | [ ] House B |
| F1.6 | Invoice export detail | Open export A → leave → open export B | [ ] Export B |
| F1.7 | Support compose | Compose for client A → leave → compose for client B | [ ] Client B |
| F1.8 | Recurrence form | Fill pattern → leave → reopen | [ ] Empty/default form |

### F2. Shell tabs (soft refresh; drafts cleared)

| # | Tab | Steps | Pass |
|---|-----|-------|------|
| F2.1 | Clients | Type into create/edit fields if exposed → switch to Jobs → back to Clients | [ ] Abandoned form drafts cleared; list reloads |
| F2.2 | Jobs | Same for create-job drafts | [ ] Drafts cleared; list reloads |
| F2.3 | Billing exports | Select visits for create → switch tab → back | [ ] Selection cleared; lists reload |
| F2.4 | Contractor credentials | Start create fields → switch tab → back to list | [ ] Create fields cleared; list reloads |
| F2.5 | Home alerts | Switch away and back | [ ] Does **not** hard-reset (permanent until logout) |

### F3. Logout cleanup

| # | Steps | Pass |
|---|-------|------|
| F3.1 | Log in → visit Home + start contractor onboarding if available → Logout → Log in again | [ ] No leftover home-alerts / onboarding funnel state |

Automated coverage: `test/core/getx/put_fresh_test.dart`, `test/core/getx/controller_freshness_regression_test.dart`, `test/app/controllers/auth_logout_reset_test.dart`.

