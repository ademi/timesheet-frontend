# Design delta — Flutter restructure spec vs prior migration docs

**Date:** 2026-07-26  
**Authoritative Flutter design:** [2026-07-23-frontend-contractor-domain-restructure-design.md](./2026-07-23-frontend-contractor-domain-restructure-design.md)  
**Prior corpus:** Phase 1 freeze (`phase1/`), wiring guide, impact study, checklist Phases 1–6

This note records **what changed** so implementation continues from the software-team Flutter spec without re-debating locked decisions.

---

## Verdict

| Area | Action |
|------|--------|
| Flutter delivery plan | **Replace** Phase 2→6 coding order with slices **S0–S10** from the restructure design §9 |
| API shapes / auth basics | **Keep** wiring guide + OpenAPI as helpers; prefer live routers when conflict |
| Product / IA / folders | **Follow** restructure design (StaffShell, features/*, compliance, credentials) |
| Prior Phase 1 docs | **Keep** as discovery archive; update matrices where product locks changed |
| Prior Phase 2 code | Treat as **partial S0 prototype** under `lib/app/` — must realign to `lib/features/` in S0 |

---

## Locked decisions that supersede prior defaults

| Topic | Prior migration docs | New Flutter design (authoritative) |
|-------|----------------------|-------------------------------------|
| Shell names / routes | Admin shell `/v2/admin/*`, contractor `/v2/contractor/*` | **StaffShell** `/staff/*`, **ContractorShell** `/contractor/*` |
| Folder layout | Flat `lib/app/` + module stubs | **`lib/features/<domain>/`** + `core/` + `shared/`; no new screens in flat `lib/app/views/` |
| Dio clients | `ApiClient` + `AttendanceApiClient` | **Single `ApiClient`**; delete `AttendanceApiClient` when attendance deleted |
| Session API | `SessionController` (login body + optional me/context) | **`SessionService`**: always `GET /v1/auth/me/context` after login/refresh/switch/resume |
| Gateway | DOMAIN_V2 skips portal → login | Gateway: **Sign in** + **Register as contractor** + optional landing link; delete admin/attendance cards |
| Client invite acknowledge | Out of mobile V1 / separate web | **In Flutter V1** — `/invites/client/:token` |
| Form templates | Consume + submit only | Staff may CRUD templates under jobs/forms; still no records-engine |
| Documents | upload-url → PUT → finalize | Same + **`/content` proxy** when `proxy_required`; credentials vault ownership |
| Credentials | Treated as generic docs | Full **credentials** domain (types allowlist, reviews, eligibility, MFA) |
| Compliance / NDIS privacy | Mostly out of Flutter planning | **In V1**: legal events, notices, consents, rights, export, access history, incidents |
| Rates | Simple hourly engagement rates | **Rate bands** (`base`, `evening`, `night`, `saturday`, `sunday`, `public_holiday`) |
| Subscriptions | No Flutter UI; defensive expired | Status chip + **billing deep-link** (`BILLING_URL`); no checkout |
| Company register | Landing only | Unchanged (landing) |
| Legacy code | Feature-flag / gradual | **Delete** as each slice lands — no `lib/legacy/` |
| Delivery | Phases 1–6 | **S0–S10 skeleton-first vertical slices** |
| Platforms | Implied | **Web + mobile every screen**; GPS check-in mobile-only (web message) |
| State management | GetX | **Keep GetX** (no Riverpod/BLoC/GoRouter) |

---

## Domains added to Flutter V1 (were thin or missing before)

1. Contractor register with Terms/Privacy versions (`platform_terms` / `privacy_policy`)
2. Onboarding funnel (legal → notices → consents → accept → credentials)
3. Credentials vault + staff review + eligibility_incomplete UX
4. Document content proxy for restricted evidence
5. Compliance ops (rights, privacy export, access history, incidents)
6. Engagement sharing grant (`allow_source_evidence` on accept)
7. Rate bands + band_breakdown on payment lines
8. Public client-invite acknowledge route
9. `PermissionGuard` (anyOf/allOf) in addition to AuthGuard / ActorGuard

---

## Domains still Out (aligned)

- Records-engine / NDIS client packs (`/v1/records/*`)
- Company self-registration in Flutter
- In-app GoCardless checkout/cancel
- Retention / legal-hold admin UI
- Platform admin console
- Visual rebrand
- Employee clock / PIN / old shift board / employee payroll periods

---

## Mapping prior Phase work → new slices

| Prior work | Maps to | Notes |
|------------|---------|-------|
| Phase 1 OpenAPI / scope / errors / spikes | Pre-S0 discovery | Keep; update matrices for new locks |
| Phase 2 JwtClaims, Auth switch-tenant/me-context | **S0** | Reuse logic inside `SessionService` |
| Phase 2 dual shell stubs (`/v2/...`) | **S0** | Rename routes to `/staff/*`, `/contractor/*`; move under `features/shell` |
| Phase 2 AppPermissions / ApiFailure | **S0** | Extend with compliance/credentials/billingGate/proxy_required |
| Phase 2 DocumentService | **S3** | Add finalize `credential_id`, content proxy, poll scan |
| Phase 2 module stubs under `lib/app/data` | Temporary | Relocate into `features/*/data` during S0–S4; do not grow flat `lib/app` |

---

## Compile-time defines (updated)

| Define | Purpose |
|--------|---------|
| `API_BASE_URL` | Existing |
| `BILLING_URL` | Landing billing page (subscription CTA) |
| `LANDING_URL` | Optional “Provider signup” on gateway |
| `TERMS_VERSION` / `PRIVACY_VERSION` | Public register until public legal-read exists |
| `DOMAIN_V2` | Optional during transition; target end-state is V2-only (no legacy portal) |

---

## Implementation rule going forward

1. Open **[2026-07-23-frontend-contractor-domain-restructure-design.md](./2026-07-23-frontend-contractor-domain-restructure-design.md)** as the build bible.
2. Track work in **[implementation-checklist.md](./implementation-checklist.md)** using **S0–S10**.
3. Use **[frontend-api-wiring-guide.md](./frontend-api-wiring-guide.md)** + live `/docs` for JSON fields; if conflict with restructure design paths, prefer **live routers** + restructure §6–§7.
4. Do not invent endpoints or NDIS-certifying copy (§5).
