# V1 mobile / Flutter scope matrix

**Status:** Updated 2026-07-26 to match [Flutter restructure design](../2026-07-23-frontend-contractor-domain-restructure-design.md)  
**Packaging:** One Flutter app — **StaffShell** + **ContractorShell**

| Area | In | Out | Later |
|------|----|-----|-------|
| Dual-shell routing by `actor_type` | Yes (`/staff/*`, `/contractor/*`) | | |
| GetX state / routing | Yes | Riverpod / BLoC / GoRouter | |
| Web + mobile every V1 screen | Yes | | |
| GPS check-in / complete | Mobile | Web (message only) | Staff override |
| JWT permissions + me/context session | Yes | | |
| First login / mcp | Yes if backend requires | | |
| Gateway: Sign in + contractor register | Yes | Admin/attendance portal | |
| Company public register | | Landing only | |
| Contractor register (+ Terms/Privacy versions) | Yes | | |
| Onboarding funnel (legal/notices/consents/accept/creds) | Yes | | |
| Credentials vault + staff review + eligibility UX | Yes | | |
| Documents upload/finalize + content proxy | Yes | | |
| Engagements lifecycle + sharing grant | Yes | Magic-link accept | |
| Clients / sites / contacts | Yes | Records-engine packs | |
| Client invite acknowledge (public route) | Yes | | |
| Form templates (staff) + visit submit | Yes | | |
| Jobs + recurrence generate | Yes | Recurrence regenerate if no API | |
| Visits board + contractor check-in/complete | Yes | Employee clock | |
| Contractor timetable / availability / leave | Yes | | |
| Engagement **rate bands** + payment batches | Yes | CSV export | Own-batches API |
| Contractor payments via visits filter | Yes | | |
| Compliance ops (rights, export, access history, incidents) | Yes | Retention/legal-hold UI | |
| Subscription status + billing deep-link | Yes | In-app GoCardless checkout | |
| Notifications devices/events | Yes | Stub email/sms log | |
| Tenant members / branches in Settings | Yes as needed | platform.admin console | |
| PIN / employees / old scheduling / payroll periods | | Deleted as slices land | |
| Records-engine / NDIS client packs | | V1 | Backend later |
| Visual rebrand | | V1 | |

## Shell destinations (V1)

**Staff:** Home · Workforce · Clients · Jobs · Visits · Payments · Compliance · Settings  

**Contractor:** Home · Visits · Schedule · Credentials · Profile (+ onboarding outside tabs)

## Product locks applied

- Landing: company register + GoCardless
- Flutter: contractor register + all authenticated product UI
- No NDIS-certifying / “Verified by Rostiq” copy
- Delete legacy employee UX as each replacement slice ships
