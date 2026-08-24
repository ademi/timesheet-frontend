# Manual test guide — Phases 1–6 (roster + NDIS billing)

Use this to walk the Flutter app through everything shipped in [frontend-integration-plan.md](frontend-integration-plan.md) Phases 1–6. Phase 7 (contractor legal versions) is **not** in scope.

**Suggested order:** run **Setup**, then the **golden path** once, then the leftover phase checklists.

Tick boxes as you go. Record failures with: screen, action, expected, actual, screenshot.

---

## 0. Setup

### Backend (must already be true)

- [x] Migrations **V024–V031** applied
- [x] NDIS catalogue sample imported (items such as `01_011_0107_1_1` exist)
- [x] MMM postcode sample imported
- [x] Dev admin / owner role has `billing.view` and `billing.manage`
- [x] API reachable from the app (default in this repo: `http://11.0.0.98:8000` unless you override `API_BASE_URL`)



### Accounts


| Role                                            | Why                                                           |
| ----------------------------------------------- | ------------------------------------------------------------- |
| **Staff admin** (owner/admin)                   | Roster, clients, billing, NDIS pickers                        |
| **Contractor** (approved engagement)            | Check-in / Complete so a visit becomes `completed` for export |
| Optional: staff user **without** `billing.view` | Confirm Billing is hidden                                     |




### Devices

- Staff tests: web, Windows, or mobile — all fine
- **Check-in / Complete is disabled on Flutter web** (GPS). Use an **Android/iOS emulator or device** for Phase 5 completion, or complete the visit via API if you only have web



### Seed data to create first (staff)

Create these once; later phases reuse them.

1. **Client A — Patient with NDIS**
  - Clients → add client (type stays Patient)
  - Open the client → **Details** tab → set **NDIS number** to something like `430123456`
  - Add a **location** with a real AU postcode from the MMM sample (e.g. a known national/remote postcode)
2. **Client B — Patient without NDIS**
  - Same type, **do not** fill NDIS
  - Add at least one location
3. **Worker**
  - Workforce → invite (use mixed-case email like `Alex.Worker@example.com` — Phase 2.2 checks lowercase)
  - Finish contractor register + onboarding so they can check in
4. Optional: **Settings → Form templates** — create one template named `Session notes` so Phase 6 can attach it

---



## Golden path (covers most of Phases 2–6 in one story)

Do this first. It creates a billable visit end-to-end.

### A. Staff — book support with NDIS + tasks

1. Log in as **staff admin**.
2. Confirm bottom/side nav shows: Home, Workforce, Clients, **Roster**, Payments, **Billing**, Settings.
3. Open **Clients** → Client A.
  - [x] Header shows `NDIS 430123456` (or whatever you saved)
     [ ] No amber “NDIS number not captured” banner
     [ ] **Details** tab row **NDIS number** shows the same value
4. On **Support** tab, tap **Start ongoing support** (or **Book one session** if ongoing already exists).
5. Unified composer opens (`/staff/support/compose`).
  - [x] Step chips: **Type · Location · Schedule · Details**
6. **Type:** choose **Ongoing support** (or **One session** if this client already has ongoing). Confirm client is pre-filled. Tap **Next**.
7. **Location:** pick the site with the postcode. Tap **Next**.
8. **Schedule:**
  - Ongoing: **Ends on** defaults to about **one year** after start; pick weekdays; set start/end **time pickers** (not overnight); **Required workers** = 1; optionally pick a worker.
  - One session: set start/end; optional **Worker**; **Publish immediately** on.
  - Tap **Next**.
9. **Details:**
  - [x] Section title is **Care plan tasks** (ongoing) or **Shift tasks** (one session)
     Add preset task (e.g. Personal care) plus a custom line
     Search **NDIS support item (optional)** for `self-care` or `01_011_0107_1_1` and pick a catalogue row
     Optionally tick a form template
     Tap **Save and fill roster** (ongoing) or **Book session** (one session)
10. [ ] App lands on **Roster** with this **client** filtered
11. [ ] A **Shift** tile appears on the expected civil day (not labelled “Visit”)



### B. Staff — visit-level billing fields

1. Open the shift → open the assigned **visit**.
  - [ ] Header shows `NDIS 430123456`
    - [x] Section **NDIS support item** shows the catalogue name/code (inherited from the job/default)
    - [x] Section **Price tier** shows **Price tier override** with **Auto (MMM postcode)** / National / Remote / Very remote
    - [x] Section is labelled **Shift tasks** (not “Tasks”)
    - [x] Care-plan titles you entered appear as task rows
2. Change **Visit-level NDIS item** to a different catalogue item. Reload the visit.
  - [x] New item stuck
    - [x] Helper: “Editable while scheduled and unpaid.”
3. Set **Price tier override** to **Remote**. Reload.
  - [x] Value is Remote
4. If a task has an NDIS code, enter **billable minutes** (e.g. `60`). Save.
  - [x] Minutes persist
    - [x] Copy about multi-line export is visible when tasks are coded
5. Enter minutes larger than the visit length (e.g. `999`).
  - [x] Red warning: task minutes exceed visit duration



### C. Contractor — complete the visit (needed for export)

1. On a **phone/emulator**, log in as the **contractor**.
2. Open **Visits** → this visit → **Check in** (allow location) → **Complete**.
  - [x] Status becomes completed
    - [x] Staff visit detail then shows support item / price tier **locked** (“Locked after check-in or payment.”)



### D. Staff — invoice export

1. Staff → **Billing** → app bar **Invoice exports**.
2. Chip **Create export** → pick a **Period** that includes the visit.
3. Expand the visit tile.
  - [x] Preflight: **Visit completed** OK
    - [x] **Visit support item** or **Task billable minutes** OK
    - [x] **Price tier** OK (override) or **Price tier / postcode** warning if Auto
4. Tick the visit → **Create export (1)**.
  - [x] New row on **Exports** (status ready/succeeded)
5. Open **Export detail**.
  - [x] Lines show price tier, participant NDIS number, amounts
6. **Download CSV** / share.
  - [x] File opens; NDIS number and support item appear
7. **Void export** → confirm **Void this export?**
  - [x] Status voided
    - [ ] Re-export of the same visit is allowed

---



## Phase 1 — Foundation (data layer)

There is almost no dedicated UI. Prove the new APIs and gates from the shell.

### 1.1 Permissions and nav

1. Log in as **admin/owner**.
  - [ ] **Billing** appears in staff nav
     [ ] Opening it loads **Invoice exports** without a crash
2. Log in as a staff user **without** `billing.view` / `billing.manage`.
  - [ ] **Billing** is **hidden**
     [ ] Deep-link `/staff/billing/exports` is blocked / redirected (permission), not a blank crash
3. Admin again: open any screen with the NDIS picker (job detail or visit detail).
  - [ ] Typing in the picker returns catalogue rows (proves `GET /ndis-catalogue/items` + `jobs.manage` or `billing.view`)



### 1.2–1.3 Models and repositories (smoke)

After golden path, you already proved:


| You saw in UI                 | Backend field                             |
| ----------------------------- | ----------------------------------------- |
| Visit NDIS picker             | `support_item_code` / `support_item_name` |
| Price tier dropdown           | `price_tier_override`                     |
| Task minutes                  | `billable_minutes`                        |
| Export list/detail/CSV        | invoice export APIs                       |
| Care plan tasks on new visits | `task_template` / visit tasks             |


- [ ] No JSON parse errors in logs when opening roster, visit detail, billing



### 1.4 Error copy

On visit detail, try to set a garbage code if the picker allows free text, or force a clear then invalid pair.

- [ ] Invalid shape → user-facing message (not a raw stack trace)
- [ ] Unknown catalogue code → “not in catalogue” style message
- [ ] Duplicate ongoing support for the same client → friendly **standing job exists** copy (try **Start ongoing support** twice on Client A)

---



## Phase 2 — Roster correctness



### 2.1 Tenant timezone / horizon

1. Settings → timezone field **Timezone (e.g. Australia/Sydney)** — set `Australia/Sydney` and save (if the API stores it).
2. Open **Roster**.
  - [ ] If conversion works: **no** device-timezone warning
     [ ] If conversion is unavailable: grey helper *“Times use your device timezone while tenant timezone conversion is unavailable.”*
3. Create ongoing support whose first occurrence is **today in Sydney**, from a machine whose clock is UTC or US.
  - [ ] Tile lands on the **tenant civil day**, not shifted by ±1 day near midnight
4. Tap week **chevron** left/right several times.
  - [ ] List reloads for that week
     [ ] Horizon fill indicator may run on first open, **not** on every chevron tap
5. Leave roster open; wait; come back.
  - [ ] Existing published shifts still show (horizon did not wipe them)



### 2.2 Recurrence defaults, overnight, invites

**Default until**

1. Roster **+** → Ongoing support → Schedule.
  - [ ] **Ends on** is ~**12 months** after **Start date**
2. Change start date forward.
  - [ ] End date moves to start + 1 year if it would otherwise be before start

**Overnight block**

1. Same form: set start time `22:00`, end time `02:00` (or end before start).
  - [ ] Next/Save blocked with *“End must be after start on the same day. Overnight windows are not supported here.”* (or equivalent window error)
2. Roster copy-shift dialog: end before start.
  - [ ] *“End time must be after start.”*

**Invite email lowercase (V026)**

1. Workforce → invite `Alex.Worker@Example.COM`.
  - [ ] Invite succeeds (client lowercases before submit)
     [ ] Stored/shown email is lowercase on the worker record

**Duplicate ongoing**

1. Client who already has ongoing → **Start ongoing support** again → finish the form.
  - [ ] Inline error that this client already has ongoing support (not a generic 409)



### 2.3 Terminology (Shift, not Visit)

On **staff roster only**:

- [ ] App bar title **Roster**
- [ ] Empty/open tiles and dialogs say **Shift**
- [ ] Release / cancel / copy copy uses **shift**, not visit
- [ ] Staff **visit detail** app bar may still say **Visit** (internal model) — that is OK
- [ ] Contractor app still says **Visit** — that is OK

---



## Phase 3 — NDIS support items



### 3.1 Shared picker

Use the picker on **job detail**, **visit detail**, or unified **Details** step.

1. Tap the field **NDIS support item** / **Visit-level NDIS item**.
  - [ ] Hint: *Search catalogue by name or item number*
2. Type `self` or `01_011`. Wait ~300ms.
  - [ ] Dropdown of canonical names
3. Select a row.
  - [ ] Field shows **name**; code stored as `NN_NNN_NNNN_N_N`
4. Clear the item.
  - [ ] Both code and name empty (“None set.” on visit if locked view)
5. Type an invalid pattern (if allowed) such as `abc`.
  - [ ] Client-side format rejection before/without a 422 dump



### 3.2 Job and ongoing default

1. Settings → **Advanced Supports** (or Settings list tile for ongoing support) → open a standing job.
  - [ ] **Default NDIS support item** picker
2. Set an item on an **open** job. Reopen.
  - [ ] Value persisted (`PATCH /jobs/{id}/support-item`)
3. Unified ongoing create (Phase 6) with a default item.
  - [ ] Generated visits inherit that default
4. Job **Book one session** uses the same composer.
  - [ ] Default can be set on Details step



### 3.3 Visit and task level (staff)

1. Open a **scheduled** + **unpaid** visit.
  - [ ] Visit-level picker enabled
2. Change visit item; add/edit a **task** NDIS item.
  - [ ] Saves; 409/422 surface as inline errors if invalid
3. **Check in** (contractor) then reopen as staff.
  - [ ] Picker read-only; *“Locked after check-in or payment.”*
4. Recurrence rule form (job → edit pattern) if you use it:
  - [ ] Task template rows still accept optional per-task support codes

---



## Phase 4 — Price tier + task minutes



### 4.1 Price tier override

1. Scheduled unpaid visit → **Price tier**.
  - [ ] Dropdown: **Auto (MMM postcode)**, **National**, **Remote**, **Very remote**
     [ ] Helper: staff override wins over MMM; without override, export needs job location postcode
2. Set **Very remote**, leave screen, return.
  - [ ] Still Very remote
3. Set back to **Auto**.
  - [ ] Shows Auto
4. After the visit is in a **non-voided export**:
  - [ ] Dropdown disabled; *“Locked — already included in an export.”*



### 4.2 Task billable minutes

1. Give a shift task an NDIS code.
  - [ ] Minutes field appears (0–1440)
     [ ] Copy: tasks with codes export as **separate invoice lines**
2. Save `90` minutes.
  - [ ] Persists after refresh
3. Sum of coded task minutes **>** visit length.
  - [ ] Client warning (does not have to hard-block save)
4. Clear the task code.
  - [ ] Minutes editor hides or is irrelevant for multi-line mode

---



## Phase 5 — Invoice export UI



### 5.1 Billing shell

1. Staff with `billing.view` → **Billing**.
  - [ ] Title **Invoice exports**
     [ ] Empty state: *No invoice exports yet.* (if none)
2. Pull to refresh.
  - [ ] List reloads (`GET /billing/invoice-exports`)
3. Without `billing.manage`:
  - [ ] **Create export** chip hidden; list still visible



### 5.2 Create export

1. **Create export** chip.
2. **Period** button — choose a range with completed visits.
  - [ ] Only **completed** visits listed
3. Expand a visit that is **not** ready (no support item, or coded task missing minutes).
  - [ ] Checkbox **disabled**
     [ ] Blocking checks listed (Visit completed / Visit support item / Task billable minutes / Task minutes within visit duration)
4. Expand a ready visit.
  - [ ] Checkbox enabled
     [ ] Warnings allowed (Price tier / postcode, Closed time entry)
5. Select 1+ ready visits → **Create export (N)**.
  - [ ] Success → Exports tab
     [ ] Per-visit server errors (already exported, missing postcode) show on the tile, not only a toast
6. Try to export the same visit again before voiding.
  - [ ] 409 / already-exported feedback; visit excluded or error shown



### 5.3 Detail, CSV, void

1. Open an export.
  - [ ] Title **Export detail**
     [ ] Header: status, period, totals
     [ ] Lines: **price_tier**, **participant NDIS number**, money
2. **Download CSV**.
  - [ ] File downloads or share sheet appears
     [ ] Columns usable by a plan manager (NDIS number, item number, units, amount)
3. **Void export** (needs `billing.manage`).
  - [ ] Dialog: *Void this export?* / visits become billable again
     [ ] Cancel leaves it unchanged
     [ ] Confirm voids; CSV/detail still openable as history
4. Create a **new** export including the same visit.
  - [ ] Allowed after void

---



## Phase 6 — Unified support + care-plan demo



### 6.1 Stepped composer

**Entry points — all must open the same 4-step form**

- [ ] Roster **+** (FAB)
- [ ] Client → **Start ongoing support**
- [ ] Client → **Book one session**
- [ ] Job detail → **Book one session**

**Step Type**

- [ ] Cards **One session** and **Ongoing support**
- [ ] Roster + with no client filter: **Client**  dropdown required
- [ ] Client entry: client pre-filled (read-only)
- [ ] Next blocked until type + client chosen

**Step Location**

- [ ] Sites listed; primary selected by default
- [ ] Client with **no sites**: amber notice + **Add site for this client**
- [ ] After adding a site, returning shows it in the dropdown
- [ ] Next blocked until a location is selected

**Step Schedule**

- [ ] One session: start/end **date-time** pickers, required workers +/− (1–8), **Publish immediately**, optional **Worker**
- [ ] Ongoing: Repeats, weekdays, start/end **dates**, start/end **times**, workers +/−, optional worker (disabled when workers > 1)
- [ ] Helper when multi-slot: assign workers from the roster later

**Step Details**

- [ ] Ongoing: **Title**  required
- [ ] NDIS picker + form template chips
- [ ] Primary button: **Book session** vs **Save and fill roster**

**After save**

- [ ] Navigates to Roster with **client** (and job) filter
- [ ] Ongoing fills horizon for the tenant week
- [ ] One session with **no worker** creates an **unfilled shift**
- [ ] One session **with worker + shift tasks** creates a visit that already has those task titles



### 6.2 Care plan demo parity

**NDIS on client**

1. Client A (has number).
  - [ ] Header `NDIS …`
     [ ] Details tab **NDIS number** value (not `—`)
2. Client B (Patient, no number).
  - [ ] Amber **NDIS number not captured**
     [ ] Body text mentions Patient + Details tab
     [ ] **Open Details tab** jumps to Details
     [ ] Details row **NDIS number** is `—`
3. Enter an NDIS number on Client B, return to Overview.
  - [ ] Banner gone; header shows the number

**NDIS on visit**

1. Open a visit for Client A.
  - [ ] Line `NDIS 430123456` (may briefly say *Loading participant NDIS…*)
2. Visit whose job has no client link (rare).
  - [ ] NDIS line hidden or `NDIS —`, no crash

**Prompt in composer**

1. Roster + → pick Client B.
  - [ ] Prompt on Type and on Details
     [ ] **Open Details tab** opens client detail; returning refreshes (prompt disappears if you saved NDIS)

**Tasks**

1. Ongoing Details: section **Care plan tasks**; add titles; save.
  - [ ] Generated visits show those titles under **Shift tasks**
2. One session **without** worker, with task titles.
  - [ ] Unfilled shift; tasks may **not** exist until a worker is assigned (by design)
3. One session **with** worker + task titles.
  - [ ] Visit has **Shift tasks** immediately
4. Visit detail section title is **Shift tasks**, not “Tasks”

---



## Negative / regression sweep (quick)


| #   | Action                                         | Expect                              |
| --- | ---------------------------------------------- | ----------------------------------- |
| 1   | Next on Type with nothing selected             | Error: choose session type / client |
| 2   | Next on Location with no sites                 | Error: add a location               |
| 3   | Overnight times                                | Blocked with overnight copy         |
| 4   | Required workers 1, tap minus                  | Stays 1                             |
| 5   | Required workers 8, tap plus                   | Stays 8                             |
| 6   | Export incomplete visit                        | Not listed or checkbox disabled     |
| 7   | Export with no support item and no coded tasks | Blocked preflight                   |
| 8   | Edit support item after check-in               | Locked                              |
| 9   | Edit price tier after export                   | Locked                              |
| 10  | Billing user without manage                    | No create/void                      |
| 11  | Contractor on **web**                          | Check in / Complete disabled (GPS)  |
| 12  | Second ongoing support same client             | Friendly duplicate error            |


---



## Sign-off


| Phase                 | Golden path        | Checklist leftovers | Pass? | Notes |
| --------------------- | ------------------ | ------------------- | ----- | ----- |
| 1 Foundation          |                    | § Phase 1           |       |       |
| 2 Roster              | A, week chevrons   | § Phase 2           |       |       |
| 3 NDIS items          | A–B pickers        | § Phase 3           |       |       |
| 4 Tier + minutes      | B                  | § Phase 4           |       |       |
| 5 Invoice export      | C–D                | § Phase 5           |       |       |
| 6 Unified + care plan | A, Client B prompt | § Phase 6           |       |       |


**Tester:**  
**Build / commit:**  
**Environment (API):**  
**Date:**  