# API error catalog — Flutter UI mapper

**Sources:** [Flutter restructure design](../2026-07-23-frontend-contractor-domain-restructure-design.md) §5, §11 · wiring guide §18  
**Convention:** Non-public `{ "detail": ... }` · Public `{ "message": ... }`

| Code / situation | HTTP | UX | Copy / notes |
|------------------|------|----|--------------|
| `wrong_actor_type` | 403 | Dedicated screen | Wrong shell — sign in with correct account type |
| `must_change_password` | 403 | First-login screen | |
| `missing_permission` | 403 | Toast + hide control | Deep-link → snackbar + shell home |
| Billing / `require_active_subscription` | 402 / 403 | **billingGate** modal | “Subscription inactive” + open `BILLING_URL` |
| `subscription_expired` | 403 | Same as billingGate | Renew on website |
| `geofence_rejected` | 400 | Inline | Move closer |
| `forms_incomplete` / `required_forms_incomplete` | 400 | Inline | Complete required forms |
| `docs_incomplete` | 400 | Inline | Upload required docs |
| `scan_blocked` | 400 | Inline + retry | Re-upload / supersede |
| Scan `pending` | — | Spinner / disable ready | Do not treat as approval-ready |
| `proxy_required` | 403 | Silent redirect | Use `GET /documents/{id}/content` — never pretend signed URL was used |
| `eligibility_incomplete` | 409 | Dialog with **itemised** reasons | No “NDIS certified” / “Verified by Rostiq” / “Compliant worker” |
| `counsel_pending` | 4xx | Hard stop | “This legal document is not available yet.” |
| MFA required (credential review) | 403 | Prompt MFA / re-auth | Do not skip |
| `engagement_not_active` | 409 | Banner | Contact admin |
| `invalid_visit_status` | 409 | Toast + refresh | Already checked in, etc. |
| `visit_overlap` | 409 | Inline | Generate conflict |
| `standing_job_exists` | 409 | Inline | |
| `contractor_not_found` | 404 | Inline (invite) | |
| `hard_split_violation` | 409 | Dialog | |
| `engagement_already_exists` | 409 | Toast | |
| `payment_already_paid` / `visit_already_in_batch` | 409 | Toast | |
| `visit_not_found` | 404 | Empty | |
| Invalid credentials | 401 | Inline | |
| Session / refresh invalid | 401 | Re-login | |
| Rate limit | 429 | Snackbar | “Too many attempts — try again shortly” |
| Offline | — | Retry banner | |

## Eligibility reason codes (show itemised)

Examples: `missing`, `expired`, `awaiting_scan`, `awaiting_review`, `rejected`, `consent_withdrawn`, `grant_revoked` — parse from API payload; do not invent.

## Allowed eligibility language

- “Eligible to approve based on current requirements”
- “Requirements incomplete”
- “Reviewer accepted / rejected this credential for this provider”

## Mapper note

Centralize Dio → `AppFailure` (`unauthorized`, `forbidden`, `billingGate`, `eligibilityIncomplete`, `proxyRequired`, …). Controllers must not raw-compare `detail` strings.
