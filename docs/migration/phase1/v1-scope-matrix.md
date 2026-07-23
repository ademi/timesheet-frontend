# V1 mobile scope matrix

**Status:** Locked for Flutter V1 (defaults from clarification answers, 2026-07-23)  
**Packaging:** One Flutter app, dual shells (`tenant_member` admin + `contractor`)

| Area | In | Out | Later |
|------|----|-----|-------|
| Dual-shell routing by `actor_type` | Yes | | |
| JWT permissions only (no `/me/context` perms) | Yes | | |
| First login / `mcp` / `complete_first_login` | Yes | | |
| Contractor register (`POST /contractors/register`) | Yes | | |
| Company public register (`POST /public/register`) | | Landing page only | |
| Subscription / billing UI (`/v1/subscription*`) | | Landing page only | |
| Login `subscription` payload / `subscription_expired` | Defensive handling only | Checkout / plans / cancel UI | |
| Engagement invite → accept (in-app) | Yes | Magic-link deep link | Deep link polish if product asks |
| `pending_docs` limited nav (docs + visits read) | Yes | | |
| Tenant members CRUD (replace employees) | Yes | Employee PIN / kiosk | |
| Clients / sites / contacts CRM | Yes | Client login shell | |
| Map/pin picker for sites (lat/lng) | Yes | | Job map polish |
| Public client-invite acknowledge | | Mobile V1 | Separate web |
| Form template **consume + submit** | Yes | | |
| Form template **builder** | | Mobile V1 | Web / later mobile |
| Jobs + visits + tasks + recurrence generate | Yes | Recurrence regenerate (no API) | |
| Visit check-in / complete (GPS, online-only) | Yes | Offline queue | |
| PIN kiosk / clock-in-out / scheduling board (old) | | Removed (404) | |
| Contractor timetable / availability / leave | Yes | | |
| Engagement rates + payment batches | Yes | CSV/Excel export | Own payment-batches list API |
| Contractor payments via `visits?payment_status=` | Yes | | Dedicated own-batches endpoint |
| Attendance adjustments (visit-linked) | Yes | | |
| Weekly attendance report | | Removed | |
| Employee balance / payroll periods | | Removed | |
| Notifications devices + engagement/visit events | Yes | Stub email/sms delivery log | Inbox polish |
| `platform.admin` shell | | Out of app | |
| Force-update / min-version API | | No backend yet | Store messaging + coordinated cutover |

## Shell destinations (V1)

**Admin (`tenant_member`):** Hub · Team (members) · Contractors/Engagements · Clients · Jobs/Visits · Payments · Forms (consume/attach) · Branches/Settings  

**Contractor:** Visits · Visit detail · Timetable · Documents · Payments (via visits) · Switch tenant / Profile  

## Product defaults applied

- Form builder → **Out** (consume + submit only)
- Client CRM → **In**
- Map/pin for sites → **In**
- Engagement invite deep link → **Out** (in-app notification → accept)
- Store force-update → **Later** (coordinated cutover messaging)
- Company public register → **Out** (landing page only; Flutter starts at login)
- Subscriptions / billing → **Out** (landing page only; no Flutter checkout UI)
