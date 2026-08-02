# Backend issues for API developer

**Audience:** API / backend team  
**From:** Flutter frontend dogfood / manual QA (staff shell)  
**Date:** 2026-08-02  
**App routes observed:** `/staff/workforce`, `/staff/compliance`  
**Related history:** [migration/backend-handoff-contractor-register-nested-txn.md](./migration/backend-handoff-contractor-register-nested-txn.md) (BH-001–BH-011)

This file lists backend fixes / contract gaps from Flutter V1 dogfood. Status below reflects the API response after the 2026-08-02 backend pass.

---

## Priority summary

| ID | Priority | Status | Topic |
|----|----------|--------|-------|
| API-001 | **P0** | **Fixed** | Staff Rights tab: `GET /v1/compliance/rights-requests` → **200** list |
| API-002 | P1 | **Fixed** (Option A) | Staff **list** endpoint for rights requests |
| API-003 | P1 | **Fixed** (preferred) | Staff credential metadata without sharing grant |
| API-004 | P2 | **Fixed** | Public legal-document read for contractor register |
| API-005 | P2 | **Confirmed** | Access-history + documents + sharing-access-requests stable |
| API-006 | **P0** | **Fixed** | Staff Incidents: `GET /v1/compliance/incidents` → **200** list |

---

## API-001 / API-002 — Rights list

### Decision

**Fix** — Option A.

### Final contract

```http
GET /v1/compliance/rights-requests?limit=100&status=<optional>
Authorization: Bearer <staff_token>
```

| Field | Value |
|-------|--------|
| Permission | `compliance.rights.manage` |
| Scope | JWT tenant; includes requests with `tenant_id` match **or** contractor engaged with tenant |
| Query | `limit` 1–500 (default 100); optional `status` |
| Success | `200` → `RightsRequestOut[]` (empty `[]` ok) |
| Missing permission | `403` (not 405) |

### Example 200

```json
[
  {
    "id": "…",
    "requester_user_id": "…",
    "contractor_id": "…",
    "tenant_id": null,
    "request_type": "access",
    "status": "received",
    "scope_summary": "Copy of my records",
    "due_at": "2026-09-01T00:00:00Z",
    "notify_prior_recipients": false,
    "created_at": "…",
    "updated_at": "…"
  }
]
```

### OpenAPI updated?

Yes — FastAPI route registered; appears under `/docs`.

---

## API-003 — Credential metadata without sharing grant

### Decision

**Fix** — preferred: metadata list does **not** require sharing grant. `sharing_grant_required` remains for source download / content / evidence review.

### Final contract

```http
GET /v1/tenants/current/contractors/{contractor_id}/credentials
Authorization: Bearer <staff_token>
```

| Field | Value |
|-------|--------|
| Permission | `credentials.read` |
| Scope | Tenant must have an engagement with the contractor (else `403` `forbidden`) |
| Grant | **Not** required for list |
| Body | `200` → `CredentialOut[]` (types, statuses, dates, `evidence_presence`; no file URLs) |
| Masked id | Included only when active grant covers the type **and** App9 allows display |

### Example 200 (no grant)

```json
[
  {
    "id": "…",
    "contractor_id": "…",
    "credential_type": "police_check",
    "issuer": "ACIC",
    "jurisdiction": "AU",
    "identifier_masked": null,
    "status": "active",
    "provenance_state": "contractor_asserted",
    "evidence_presence": "present",
    "created_at": "…",
    "updated_at": "…"
  }
]
```

### OpenAPI updated?

Yes — behaviour change on existing route (response model unchanged).

---

## API-004 — Public legal document read

### Decision

**Fix**

### Final contract

```http
GET /v1/public/legal-documents/current?doc_key=platform_terms
GET /v1/public/legal-documents/current?doc_key=privacy_policy
```

| Field | Value |
|-------|--------|
| Auth | None |
| Rate limit | `60/minute` |
| Success | `200` → `{ doc_key, version, content_md, content_hash, effective_at, counsel_pending }` |
| Missing | `404` `legal_document_unavailable` |
| Production | `counsel_pending` versions still fail closed (`counsel_pending_policy`) |

### OpenAPI updated?

Yes — public router.

---

## API-005 — Contracts confirmed (no regress)

| Surface | Live contract |
|---------|----------------|
| Access history | `GET /v1/compliance/access-history?credential_id=<uuid>&limit=100` — perm `compliance.audit.view`; tenant requires `credential_id` |
| Documents list | `GET /v1/documents?owner_type=…&owner_id=…` — both required |
| Sharing access requests | Staff `POST /v1/tenants/current/engagements/{id}/sharing-access-requests`; contractor `GET /v1/contractor-me/sharing-access-requests` + `POST …/{id}/approve` (no contractor create POST) |

`limit` on access-history is now accepted (1–500, default 100).

---

## API-006 — Incidents collection GET

### Decision

**Fix**

### Final contract

```http
GET /v1/compliance/incidents?limit=100&status=<optional>
Authorization: Bearer <staff_token>
```

| Field | Value |
|-------|--------|
| Permission | `compliance.incidents.manage` |
| Query | `limit` 1–500 (default 100); optional `status` |
| Success | `200` → `IncidentOut[]` (empty `[]` ok) |
| Missing permission | `403` (not 405) |

### OpenAPI updated?

Yes — FastAPI route registered; appears under `/docs`.

---

## Suggested response back to Flutter

| ID | Decision | Final contract | OpenAPI |
|----|----------|----------------|---------|
| API-001 | Fixed | `GET /v1/compliance/rights-requests` + `compliance.rights.manage` | Yes |
| API-002 | Fixed (Option A) | same as API-001 | Yes |
| API-003 | Fixed (preferred) | Metadata without grant; engagement required | Yes |
| API-004 | Fixed | `GET /v1/public/legal-documents/current?doc_key=` | Yes |
| API-005 | Confirmed | Paths unchanged; `limit` on access-history | Yes |
| API-006 | Fixed | `GET /v1/compliance/incidents` + `compliance.incidents.manage` | Yes |

---

## Flutter client status

| ID | Flutter |
|----|---------|
| API-001 / 002 | Uses `GET /v1/compliance/rights-requests?limit=100` |
| API-003 | Passes `engagement_id` on staff credential metadata list |
| API-004 | `ApiPaths.publicLegalDocumentsCurrent` available (register still uses bundled assets until wired) |
| API-005 | Access-history sends `credential_id` + `limit` |
| API-006 | Uses `GET /v1/compliance/incidents?limit=100` (+ optional `status`); create/close refresh from list |

**Note:** Restart the API process after deploying API-006 so OpenAPI / live routes include collection GET. If the server was started before the fix, Flutter will still see 405 until restart.

---

## Out of scope for this handoff

- Records-engine / NDIS client packs  
- In-app GoCardless checkout  
- Platform admin console  
- Flutter-only UI bugs (unless caused by wrong API contract)

---

*Primary open dogfood blocker (API-001 Rights GET 405) is resolved. API-006 Incidents GET 405 is also resolved.*
