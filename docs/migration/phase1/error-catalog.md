# API error catalog — Flutter UI mapper

**Source:** [frontend-api-wiring-guide.md](../frontend-api-wiring-guide.md) §18 + clarification answer log  
**Convention:** Non-public APIs use `{ "detail": "..." }` (string or structured). Public APIs use `{ "message": "..." }`.

Use these exact `detail` / code strings in the client mapper. Prefer **dedicated screen** for actor/session hard failures; **toast / inline** for recoverable validation.

| Code / detail | HTTP | UX | Suggested copy |
|---------------|------|----|----------------|
| `wrong_actor_type` | 403 | Dedicated screen | “This account can’t use this area. Sign in with the correct account type.” |
| `must_change_password` | 403 | Force password screen | Route to first-login / change password |
| `missing_permission` (RBAC style) | 403 | Toast | “You don’t have permission for this action.” |
| `subscription_expired` | 403 | Toast / blocking banner (no billing UI in Flutter) | “Subscription expired — renew on the website.” Checkout stays on landing page. |
| `geofence_rejected` | 400 | Inline on visit | “You’re outside the allowed area. Move closer and try again.” |
| `forms_incomplete` / `required_forms_incomplete` | 400 | Inline | “Complete required forms before finishing the visit.” |
| `docs_incomplete` | 400 | Inline (engagement) | “Upload required documents before approval.” |
| `scan_blocked` | 400 | Inline + retry | “File failed security scan. Re-upload a clean file.” |
| `engagement_not_active` | 409 | Inline / banner | “Engagement isn’t active. Contact your admin.” |
| `invalid_visit_status` | 409 | Toast + refresh | “Visit status changed. Refresh and try again.” (e.g. already checked in) |
| `visit_overlap` | 409 | Inline (generate) | “Overlapping visit — adjust window or use partial generate.” |
| `standing_job_exists` | 409 | Inline (job create) | “An open standing job already exists for this client.” |
| `contractor_not_found` | 404 | Inline (invite) | “No contractor registered with that email/phone.” |
| `hard_split_violation` | 409 | Dedicated / dialog | “This user can’t be invited as a contractor.” |
| `engagement_already_exists` | 409 | Toast | “Engagement already exists for this contractor.” |
| `payment_already_paid` | 409 | Toast | “Visit is already paid.” |
| `visit_already_in_batch` | 409 | Toast | “Visit is already in a payment batch.” |
| `visit_not_found` | 404 | Empty / back | “Visit not found.” |
| Invalid credentials (login) | 401 | Inline | “Invalid email, phone, or password.” |
| Refresh / session invalid | 401 | Clear session → login | “Session expired. Please sign in again.” |

## Suspended-engagement gap (known)

Service may allow visit **complete** while suspended JWT omits `visits.complete` → expect **403**. Show: “Session limited — refresh or contact admin.” Track backend fix (clarification Eng-3).

## Mapper implementation note (Phase 2)

Centralize in a typed failure mapper (Dio → `ApiFailure`). Do not scatter raw `detail` string compares across controllers.
