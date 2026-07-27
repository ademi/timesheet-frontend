# Manual QA — MVP delivery (admin minimum path)

**Goal (admin):** platform can do the basics — **log in → check in with the patient → fill shift / progress notes → complete → log out**.

**Audience:** Flutter + API smoke for a 2-day delivery gate  
**Not in scope for this MVP gate:** payroll batches, compliance ops, credentials review UI polish, full onboarding funnel dogfood, rich NDIS progress-report product UI.

**Related slice QA (optional deeper):** [manual-qa-s5.md](./manual-qa-s5.md) · [manual-qa-s6.md](./manual-qa-s6.md) · [manual-qa-s7.md](./manual-qa-s7.md)

---

## What “pass” means


| Admin ask                 | Pass if                                                                                             |
| ------------------------- | --------------------------------------------------------------------------------------------------- |
| Log in                    | Staff and contractor can sign in and land in the correct shell                                      |
| Check in with the patient | Contractor checks in on a **visit** for a **client/site** (patient location) on **mobile** with GPS |
| Shift data                | Visit shows schedule window; tasks can be toggled done                                              |
| Progress reports          | Contractor submits required visit form with **notes** (MVP progress note)                           |
| Finish + log out          | Visit **Complete**, then **Log out** returns to gateway/login                                       |


---



## 0. Prerequisites



### 0.1 API

- Backend running (local or staging), BH-001–010 applied.
- Demo staff available (seed): `admin@demotenant.example` / `ChangeMe123!`
- At least one **contractor** with an **active** engagement and `visits.check_in` / `visits.complete` (and form submit perms as required by API).



### 0.2 Devices


| Step                             | Device                                                          |
| -------------------------------- | --------------------------------------------------------------- |
| Staff setup (client, job, visit) | Chrome/web **OK**                                               |
| Contractor check-in / complete   | **Physical phone or emulator with location** — web disables GPS |




### 0.3 Run commands

```bash
# Staff setup (web)
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=DOMAIN_V2=true

# Contractor field loop (mobile)
flutter run -d <device> \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=DOMAIN_V2=true
```

Use your real API base URL if not localhost. Phone must reach that host (emulator: often `10.0.2.2:8000` on Android).

### 0.4 Location tip (check-in)

- Client **site** must have **latitude / longitude**.
- For geofence-enforced visits, stand near that point (or temporarily use a site at your current GPS / set geofence mode that allows the test).

---



## Part A — Staff: create the patient visit (setup)

Do this once so the contractor has something to check into.

### A1 — Staff login

- [x] Open app → Sign in as `admin@demotenant.example` / `ChangeMe123!`
- [x] Land in **Staff** shell (not contractor / wrong-actor)
- [x] **Log out** works (optional smoke) → can log back in



### A2 — Client + site (“patient” location)

- [x] Staff → **Clients** → create client (name required)
- [x] Open client → add **site** with address + **lat/lng** (required in Flutter)
- [x] Site saved and visible on client detail



### A3 — Form template (for progress notes)

- [x] Staff → **Jobs** → **Form templates** (or equivalent)
- [x] Create a simple tenant-level template (e.g. name `Progress notes`)
- [x] Template appears in list



### A4 — Job + attach form + generate visit

- [x] Staff → **Jobs** → create job  
  - Location = client **site** (XOR branch)  
  - Standing jobs need client as required by UI
- [x] Job detail: attach the form template to the job / recurrence rule (required)
- [x] Recurrence **Generate** (or create visit) so a **visit** exists in the next window
- [x] Staff → **Visits**: row shows for that job/client; open detail → status **scheduled** (or equivalent)

**Setup exit:** one scheduled visit exists for an active contractor against a geolocated client site, with a required form on the visit.

---



## Part B — Contractor MVP loop (delivery path)

Run on **mobile** with location permission allowed.

### B1 — Log in

- [x] Contractor signs in with active-engagement credentials
- [x] Lands in **Contractor** shell
- [x] **Visits** tab/list loads upcoming visits



### B2 — Open visit (shift data visible)

- [x] Open the scheduled visit
- [ ] Screen shows:
  - [x] Job / client context
  - [x] **Scheduled start → end** (shift window)
  - [x] Status (scheduled)
  - [x] Tasks list (may be empty — OK if API sent none)
  - [x] Required forms section (template name / required flag)



### B3 — Check in with the patient

- [x] Grant location if prompted
- [x] Tap **Check in**
- [x] Success → status becomes **checked_in** (or API equivalent)
- [ ] Failure cases (record, do not block MVP if setup was wrong):
  - [ ] Outside geofence → clear `geofence_rejected` style message
  - [ ] Inactive engagement → clear error (not a crash)



### B4 — Shift work + progress report (MVP)

**Tasks (shift checklist):**

- [x] If tasks exist: toggle at least one **done** → stays checked after refresh

**Progress report (MVP = form notes):**

- [x] Enter notes in the **Notes (payload)** field (e.g. `Patient settled; meds given as charted.`)
- [x] Tap **Submit** on the required form
- [x] Snackbar / confirmation; submission listed under submitted forms
- [x] Empty notes still submitable (app may send default `"Submitted"`) — optional check

> **Expectation note for stakeholders:** this is a **notes payload against a form template**, not a multi-section clinical progress-report product.



### B5 — Complete the visit

- [x] Tap **Complete**
- [x] Status → **completed**
- [x] If required form missing → clear `forms_incomplete` / similar (fix that required form was submitted first)



### B6 — Log out

- [x] Use **Log out** (shell / home / profile)
- [x] Returns to gateway or login
- [x] Re-open app: not still inside contractor session without credentials (token cleared)

---



## Part C — Quick regression (same day)

- [ ] Staff can still see the visit as completed on **Visits** board
- [ ] Contractor cannot check in again on a completed visit (buttons gone / disabled)
- [ ] Web contractor: check-in/complete **disabled** with mobile-app message (policy OK)

---



## Pass / fail sheet


| #   | Step                      | Pass? | Notes |
| --- | ------------------------- | ----- | ----- |
| A1  | Staff login               | ☐     |       |
| A2  | Client + site with coords | ☐     |       |
| A3  | Form template             | ☐     |       |
| A4  | Job + visit generated     | ☐     |       |
| B1  | Contractor login          | ☐     |       |
| B2  | Shift schedule visible    | ☐     |       |
| B3  | Mobile check-in           | ☐     |       |
| B4  | Tasks + form notes submit | ☐     |       |
| B5  | Complete visit            | ☐     |       |
| B6  | Log out                   | ☐     |       |


**MVP delivery gate:** all of **B1–B6** pass on mobile, with **A** completed as fixture.

---



## Out of scope (do not fail MVP for these)

- Rich progress-report UI (sections, signatures, PDF)
- Old employee shift schedule board
- Payroll / payment batches
- Compliance rights / incidents
- Credential review queue polish
- Full register → onboarding → activate funnel (nice-to-have same week, not this gate)

---



## Sign-off


| Field              | Value           |
| ------------------ | --------------- |
| Date               |                 |
| Tester             |                 |
| API base URL       |                 |
| Staff account      |                 |
| Contractor account |                 |
| Device (check-in)  |                 |
| Result             | ☐ Pass · ☐ Fail |
| Blockers           |                 |


