# Admin Feedback — Task Breakdown

Source: admin review notes (Aug 2026).  
Goal: split feedback into discrete, doable tasks. Do not start implementation from this file alone — work one task at a time.

**Out of scope for now:** anything about **visits** or **jobs** (deferred — handle later).

**Status legend:** `[ ]` todo · `[x]` done · `[~]` blocked / needs decision

---

## MVP / Product scope (open questions)

| ID | Task | Notes / decision needed |
|----|------|-------------------------|
| MVP-1 | [x] Clarify whether **shift creation** is in MVP scope | **In MVP** — admin Shift Schedule create/assign stays in scope (matches original “What is an MVP” note) |
| MVP-2 | [x] Improve copy / wording across the app (**better language**) | Done — humanized statuses, softer role copy, document wording |

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
| WF-1 | [x] Do not display **Required** section on the workforce card itself | Done — list card shows status only; required docs on detail |
| WF-2 | [x] **Order cards** by contractor status, then by name | Done — status order then displayName |
| WF-3 | [x] Add **photo caching** for contractor / workforce images | Done — in-memory bytes cache by documentId |

### Credential Review

| ID | Task | Details |
|----|------|---------|
| WF-4 | [x] Add optional **Reason Code** dropdown on credential review | Done — optional reason code dropdown |

### Contractor card — Lifecycle & engagement

| ID | Task | Details |
|----|------|---------|
| WF-5 | [x] Add option to **withdraw invite** while waiting for invite acceptance | Done — Withdraw invite + confirm → end API |
| WF-6 | [x] Add **confirm popup** before **End engagement** | Done on `refactor/client_info_update` — confirm dialog before end |
| WF-7 | [x] Improve unclear error: *"This engagement can't move to that status from here (pending docs)"* | Done — clearer invalid_transition message with next step |
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
| IC-1 | [x] Fix default contractor name after invite (**Demo Free Contractor**) — use real name or show **email** instead | Done — API `contractor_email` + displayName; seed renamed |
| IC-2 | [x] Rename **Required Categories** → **Required Document** | Done — “Required documents” on invite + detail |
| IC-3 | [ ] Move **balloons** (chips/tags?) into a **dropdown** | UI cleanup |
| IC-4 | [x] Fix **invitation emails not sent** | Done on this branch + BE `refactor/client-info-update` — API returns `invite_url`; UI shows copy dialog (real SMTP still needs `AZURE_EMAIL_ENABLED` in deploy) |
| IC-5 | [x] If contractor is **not in Rostiq**, ask admin whether to send an email | Done — invite preview + confirm (Send email / Link only / Cancel); `send_email` on create |

---

## Admin — Clients

| ID | Task | Details |
|----|------|---------|
| CL-1 | [ ] **Order** clients by type, then by name | Sort |

### Client card

| ID | Task | Details |
|----|------|---------|
| CL-3 | [x] Make **address** clickable (open maps) and **copyable** | Done — list shows primary site; tap maps / long-press copy |

### Client Types (rename & intake)

| ID | Task | Details |
|----|------|---------|
| CL-4 | [x] Rename **Types** → **Details** | Done — tab + section labels |
| CL-5 | [x] File upload on Android should open the **photos** folder / gallery | Done — ImagePicker gallery when accept is images-only |
| CL-6 | [x] Add more explanation for **Australian 100-point identification** | Done — richer help text (FE + V021 migration) |
| CL-7 | [x] Fix **Consent Method** UX; allow option to **upload a version** | Done — uploaded_scan shows picker; scan uploaded with acceptance |
| CL-8 | [x] **Intake form** should go to the **invite** part of the flow | Done — after Types/intake save, switch to Invites tab |
| CL-9 | [x] **Emergency contact phone**: number keypad; include field in **invite** | Done — intake field type `phone` (V022) + phone keypad; field remains on intake before invite |
| CL-10 | [x] Allow **sharing with contractor** for diagnoses and behavior diagnoses | Done — V022 sharing_flag requirements + existing share UI |

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
| ST-1 | [x] Default **country to AU** (dropdown); default **state to NSW** (dropdown) | Done — AU/NSW defaults + dropdowns |
| ST-2 | [x] Fix country **default value disappearing** | Done — siteCountry/siteState obs retained |
| ST-3 | [x] Clarify site form error messages (e.g. *"Address Line 1, C"*) | Done — shorter geocode error without truncation trap |
| ST-4 | [x] Flag **low-confidence geocoding** as an error (or strong warning) | Done — treated as hard fail; coords not applied |
| ST-5 | [x] Site card should **display address** | Done — full displayAddress + maps/copy |

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
4. **Copy & clarity:** ~~MVP-2, WF-7, IC-1–IC-2, CL-4, CL-6, ST-3~~ **done** (all existed on this branch)  
5. **Enhancements:** ~~WF-1–WF-5, CL-3, CL-5, CL-7, CL-9–CL-10, ST-1–ST-5~~ **done**  
6. **Product decisions:** ~~MVP-1, IC-5~~ **done**  

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
| MVP-2 | Yes (raw statuses / jargon) | Fixed |
| WF-7 | Yes (vague invalid_transition) | Fixed |
| IC-1 | Yes (Demo Free Contractor + no email fallback) | Fixed |
| IC-2 | Yes (“Required categories”) | Fixed |
| CL-4 | Yes (“Types” tab) | Fixed |
| CL-6 | Partial (thin help) → Fixed | Fixed |
| ST-3 | Yes (long geocode error truncates oddly) | Fixed |
---

## Decision log (fill in during work)

| Topic | Decision | Date |
|-------|----------|------|
| Shift creation in MVP? | **Yes** — keep Shift Schedule create/assign in MVP | 2026-08-15 |
| Default invite display: name vs email? | Prefer name; fall back to email (never UUID / Demo Free Contractor) | 2026-08-15 |
| Low-confidence geocoding = hard error? | Yes — block coords; require re-lookup | 2026-08-15 |
| Invite email when not in Rostiq? | Ask admin: Send email / Link only / Cancel | 2026-08-15 |

---

## Progress

- Active tasks: **~6** remaining (visits/jobs deferred)  
- Completed: `33`  
- Last updated: 2026-08-15
