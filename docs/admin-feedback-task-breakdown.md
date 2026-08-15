# Admin Feedback — Task Breakdown

Source: admin review notes (Aug 2026).  
Goal: split feedback into discrete, doable tasks. Do not start implementation from this file alone — work one task at a time.

**Out of scope for now:** anything about **visits** or **jobs** (deferred — handle later).

**Status legend:** `[ ]` todo · `[x]` done · `[~]` blocked / needs decision

---

## MVP / Product scope (open questions)

| ID | Task | Notes / decision needed |
|----|------|-------------------------|
| MVP-1 | [ ] Clarify whether **shift creation** is in MVP scope | Product decision |
| MVP-2 | [ ] Improve copy / wording across the app (**better language**) | Cross-cutting; track per screen as issues are found |

---

## Cross-cutting UX

| ID | Task | Area |
|----|------|------|
| UX-1 | [ ] Fix error messages that appear at the top of the screen — user must scroll up to see them | Global forms / snackbars / banners |

---

## Admin — Navigation & Home

| ID | Task | Details |
|----|------|---------|
| AD-1 | [x] Move crowded admin **menu to the left side** | Done — left `NavigationRail` on all widths (compact labels on phone) |
| AD-2 | [x] Home: stop **multiple duplicate server requests**; add **caching** | Done on `refactor/client_info_update` — permanent controller + 45s TTL / single-flight; refresh forces reload |

---

## Admin — Workforce

| ID | Task | Details |
|----|------|---------|
| WF-1 | [ ] Do not display **Required** section on the workforce card itself | Move elsewhere or show only on detail |
| WF-2 | [ ] **Order cards** by contractor status, then by name | Sort: status → name |
| WF-3 | [ ] Add **photo caching** for contractor / workforce images | Avoid refetch flicker |

### Credential Review

| ID | Task | Details |
|----|------|---------|
| WF-4 | [ ] Add optional **Reason Code** dropdown on credential review | Optional field |

### Contractor card — Lifecycle & engagement

| ID | Task | Details |
|----|------|---------|
| WF-5 | [ ] Add option to **withdraw invite** while waiting for invite acceptance | Lifecycle gap |
| WF-6 | [x] Add **confirm popup** before **End engagement** | Done on `refactor/client_info_update` — confirm dialog before end |
| WF-7 | [ ] Improve unclear error: *"This engagement can't move to that status from here (pending docs)"* | Clearer message + next step for user |
| WF-8 | [x] Make error messages **disappear** after dismiss / timeout / success | Done — dismiss button + 8s auto-clear on workforce errors |

### Payment rates

| ID | Task | Details |
|----|------|---------|
| WF-9 | [x] Hide **New Payment Rate** form on card; use a **button** that navigates to another screen | Done — list on detail; form on `/staff/workforce/detail/rate-form` |
| WF-10 | [ ] Mark **Evening, Night**, etc. rates as **optional** in UI | Label optional fields |
| WF-11 | [ ] If contractor has an **active rate**, new-rate button / copy should warn that previous rate ends and new rate starts from effective date | Messaging + behavior |
| WF-12 | [ ] Remove display of raw rate summary like `evening 47.0-night 57.0` | Cleaner presentation |

---

## Admin — Invite Contractor

| ID | Task | Details |
|----|------|---------|
| IC-1 | [ ] Fix default contractor name after invite (**Demo Free Contractor**) — use real name or show **email** instead | Product preference |
| IC-2 | [ ] Rename **Required Categories** → **Required Document** | Copy change |
| IC-3 | [ ] Move **balloons** (chips/tags?) into a **dropdown** | UI cleanup |
| IC-4 | [x] Fix **invitation emails not sent** | Done on this branch + BE `refactor/client-info-update` — API returns `invite_url`; UI shows copy dialog (real SMTP still needs `AZURE_EMAIL_ENABLED` in deploy) |
| IC-5 | [ ] If contractor is **not in Rostiq**, ask admin whether to send an email | Confirmation / prompt flow |

---

## Admin — Clients

| ID | Task | Details |
|----|------|---------|
| CL-1 | [ ] **Order** clients by type, then by name | Sort |

### Client card

| ID | Task | Details |
|----|------|---------|
| CL-3 | [ ] Make **address** clickable (open maps) and **copyable** | Client card address |

### Client Types (rename & intake)

| ID | Task | Details |
|----|------|---------|
| CL-4 | [ ] Rename **Types** → **Details** | Label change |
| CL-5 | [ ] File upload on Android should open the **photos** folder / gallery | Picker intent |
| CL-6 | [ ] Add more explanation for **Australian 100-point identification** | Help text / link |
| CL-7 | [ ] Fix **Consent Method** UX; allow option to **upload a version** | Off today |
| CL-8 | [x] **Intake form** should go to the **invite** part of the flow | Done — after Types/intake save, switch to Invites tab |
| CL-9 | [ ] **Emergency contact phone**: number keypad; include field in **invite** | Input + invite payload |
| CL-10 | [ ] Allow **sharing with contractor** for diagnoses and behavior diagnoses | Permissions / visibility |

### New Client

| ID | Task | Details |
|----|------|---------|
| CL-11 | [x] Prevent saving a client with **no information** — validate form before save | Done — Form validators + require name and email/phone |
| CL-12 | [ ] Remove **Service Agreement Notes** | Field removal |
| CL-13 | [x] After create, **route to the new client Type/Details banner** | Done — create opens detail on Types tab |
| CL-14 | [x] Fix **upload client image** returning **400** | Done on `refactor/client_info_update` — MIME guess no longer sends `image/gif` / `application/octet-stream` |

### Sites

| ID | Task | Details |
|----|------|---------|
| ST-1 | [ ] Default **country to AU** (dropdown); default **state to NSW** (dropdown) | Defaults + selects |
| ST-2 | [ ] Fix country **default value disappearing** | State retention bug |
| ST-3 | [ ] Clarify site form error messages (e.g. *"Address Line 1, C"*) | Human-readable validation |
| ST-4 | [ ] Flag **low-confidence geocoding** as an error (or strong warning) | Product: treat as hard fail? |
| ST-5 | [ ] Site card should **display address** | List / card UI |

---

## Deferred (visits / jobs — handle later)

Not tracked in active work:

- Worker working vs available for a visit
- Contractor visits: Open in Maps, Submit button position, Complete clearing form, no-incident checklist, Report to Supervisor, optional evidence
- Client → link to jobs

---

## Suggested work order

Rough priority for tackling one-by-one (adjust as needed):

1. **Broken flows first:** ~~IC-4, CL-14, AD-2~~ **done** (all three existed on this branch)  
2. **Data loss / destructive UX:** ~~WF-6, CL-11, WF-8~~ **done** (all three existed on this branch)  
3. **Navigation & layout:** ~~AD-1, WF-9, CL-13, CL-8~~ **done** (all four existed on this branch)  
4. **Copy & clarity:** MVP-2, WF-7, IC-1–IC-2, CL-4, CL-6, ST-3  
5. **Enhancements:** WF-1–WF-5, CL-3, CL-5, CL-7, CL-9–CL-10, ST-1–ST-5  
6. **Product decisions:** MVP-1, ST-4, IC-5  

---

## Branch applicability (broken-flow batch)

Verified on FE `refactor/client_info_update` / BE `refactor/client-info-update`:

| ID | Existed on this branch? | Status |
|----|-------------------------|--------|
| IC-4 | Yes | Fixed |
| CL-14 | Yes (profile photo feature present) | Fixed |
| AD-2 | Yes (delete+recreate home controller + uncached load) | Fixed |
| WF-6 | Yes (End engagement had no confirm) | Fixed |
| CL-11 | Yes (name-only check; empty contact allowed) | Fixed |
| WF-8 | Yes (sticky error banners, no dismiss/timeout) | Fixed |
| AD-1 | Yes (crowded bottom nav on phone) | Fixed |
| WF-9 | Yes (inline New Payment Rate form on detail) | Fixed |
| CL-13 | Yes (create opened Sites tab) | Fixed |
| CL-8 | Yes (Types save stayed on Types) | Fixed |
---

## Decision log (fill in during work)

| Topic | Decision | Date |
|-------|----------|------|
| Shift creation in MVP? | | |
| Default invite display: name vs email? | | |
| Low-confidence geocoding = hard error? | | |

---

## Progress

- Active tasks: **~23** remaining (excluding MVP questions; visits/jobs deferred)  
- Completed: `10` (IC-4, CL-14, AD-2, WF-6, CL-11, WF-8, AD-1, WF-9, CL-13, CL-8)  
- Last updated: 2026-08-15
