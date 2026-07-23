# Phase 1 — Spike sign-off

**Date:** 2026-07-23  
**API:** `http://localhost:8000` (`timesheet-api` 0.2.0)

## Spike results

| Spike | Contract (OpenAPI + unit/mock) | Live against localhost | Sign-off |
|-------|--------------------------------|------------------------|----------|
| 1. Login as `tenant_member` → parse JWT → admin shell eligible | Pass — `JwtClaims` + `AuthTokenModel` | Needs tenant/owner fixture from landing-page register or backend seed (Flutter does **not** call `/v1/public/register`) | **Signed** (contract) |
| 2. Login as contractor → engagements → `switch-tenant` | Pass — models + `AuthRemoteDataSource.switchTenant` tests | Needs invited/active engagement fixture; bare contractor cannot login until engaged | **Signed** (contract) |
| 3. `GET /v1/auth/me/context` vs login body parity | Pass — `MeContextModel` + datasource test; OpenAPI schemas aligned | Same auth fixture blocker | **Signed** (contract) |
| 4. Document `upload-url` → PUT → `finalize` | Pass — `DocumentRemoteDataSource` mock spike | Needs authenticated contractor with `documents.upload` | **Signed** (contract) |
| 5. Visit check-in `{lat,lng,accuracy_m}` | Pass — `VisitRemoteDataSource` + `VisitGpsBody` OpenAPI match | Needs active engagement + scheduled visit fixture | **Signed** (contract) |

## Live checks that did run

```text
dart run tool/phase1_spikes.dart health
→ health ok, ready ok, openapi timesheet-api 0.2.0 (98 paths)
```

Critical paths present in OpenAPI (see [openapi-review.md](./openapi-review.md)).

## How to re-run authenticated live spikes

Use accounts created on the **landing page** (company register) or backend seed fixtures — not via Flutter.

```bash
# optional override
set API_BASE_URL=http://localhost:8000

dart run tool/phase1_spikes.dart member --email OWNER@x --password SECRET
dart run tool/phase1_spikes.dart contractor --email C@x --password SECRET --tenant TENANT_UUID
dart run tool/phase1_spikes.dart context --email C@x --password SECRET
dart run tool/phase1_spikes.dart document --email C@x --password SECRET --owner CONTRACTOR_UUID
dart run tool/phase1_spikes.dart checkin --email C@x --password SECRET --visit VISIT_UUID --lat -33.8688 --lng 151.2093 --accuracy 12.5
```

**Out of Flutter:** `POST /v1/public/register` and `/v1/subscription*` UI (landing page only).

## Admin shell landing rule (stub)

After login, if JWT `actor_type == tenant_member` → admin shell; if `contractor` → contractor shell (multi-engagement → switch-tenant / picker first). Dual-shell route graphs are Phase 2.

## Automated verification

```bash
flutter test test/core/auth/phase1_contract_spike_test.dart \
  test/app/data/datasources/remote/auth_v2_spike_test.dart \
  test/app/data/datasources/remote/document_visit_spike_test.dart
```

All Phase 1 contract spikes **passed** on 2026-07-23.
