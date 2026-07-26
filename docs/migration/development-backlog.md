# Development Backlog (S0–S10)

Aligned to [2026-07-23-frontend-contractor-domain-restructure-design.md](./2026-07-23-frontend-contractor-domain-restructure-design.md) §9.  
Track checkboxes in [implementation-checklist.md](./implementation-checklist.md).

**Estimate:** S · M · L · XL · **Priority:** P0–P3

| Slice | Task | Priority | Est. | Notes |
|-------|------|----------|------|-------|
| S0 | `lib/features` layout + single ApiClient plan + `api_paths` | P0 | L | Port Phase 2 stubs |
| S0 | `SessionService` + me/context + permission helpers | P0 | L | Reuse JwtClaims |
| S0 | StaffShell + ContractorShell + guards + gateway rewrite | P0 | L | Routes `/staff`, `/contractor` |
| S0 | AppFailure mapper (billingGate, eligibility, proxy) | P0 | M | |
| S0 | Dart-defines BILLING_URL / LANDING_URL / TERMS / PRIVACY | P0 | S | |
| S1 | Contractor register + bundled legal versions | P0 | M | No tokens on success |
| S2 | Legal/notice/consent widgets + onboarding funnel | P0 | L | flutter_markdown |
| S3 | Credentials vault + doc upload/finalize/poll + content proxy | P0 | XL | |
| S3 | Staff credential review + MFA prompt hook | P0 | L | |
| S4 | Workforce invite/lifecycle + contractor accept grant UI | P0 | XL | Delete employee CRUD when done |
| S5 | Clients/sites/contacts + public invite acknowledge | P1 | L | |
| S6 | Jobs + form templates + recurrence generate | P0 | XL | Delete shift board when done |
| S7 | Visits board + check-in/complete (web GPS gate) | P0 | XL | Delete employee clock when done |
| S8 | Timetable / availability / leave | P1 | L | |
| S9 | Rate bands + payment batches | P1 | L | Delete old payroll periods |
| S10 | Compliance ops + notifications + billing deep-link + cleanup | P1 | L | Delete AttendanceApiClient |
| QA | Unit tests per design §10.1 | P0 | L | Parallel with slices |
| QA | Smoke checklist §10.2 | P0 | L | Manual fixtures |
| Rollout | Coordinated cutover + store messaging | P0 | M | No dual-run API |

## Manual smoke (from design §10.2)

1. Staff invite → contractor register → onboarding → accept → upload → review → approve → activate  
2. Client + site → job + generate → contractor visit → mobile check-in/complete  
3. Rate card → payment batch post; band_breakdown visible  
4. Privacy export + rights request  
5. Billing gate → opens BILLING_URL  
6. Web: staff OK; contractor check-in disabled with message  
7. Restricted doc uses `/content` proxy  

## Explicit non-work

Do not build records-engine, company register, in-app GoCardless, retention UI, or employee clock/PIN/old scheduling tests.
