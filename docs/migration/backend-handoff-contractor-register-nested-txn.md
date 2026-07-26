# Backend handoff log (Flutter → API)

**Audience:** API / backend developers  
**Branch context:** `contractor_workflow`  
**Maintained by:** Flutter migration work

> **Process:** From now on, any backend change needed for Flutter slices is recorded in this file.  
> Add a new **Issue** section (problem, expected behaviour, proposed/done change, verification).  
> Do not open separate one-off handoff files unless the topic is huge enough to split later.

---

## Issue index

| ID | Date | Status | Topic |
|----|------|--------|-------|
| BH-001 | 2026-07-26 | Proposed / applied in local tree — needs API restart + review | Contractor register nested transaction → opaque HTTP 500 |

---

## BH-001 — Contractor register nested-transaction fix

**Date:** 2026-07-26  
**File changed:** `timesheet-backend/app/modules/contractors/service.py`  
**Related Flutter work:** S1 contractor public register (`POST /v1/contractors/register`)

### Summary

While wiring Flutter S1 (public contractor register), `POST /v1/contractors/register` was returning **HTTP 500 Internal Server Error** with an empty body against the local API (`http://localhost:8000`). Investigation pointed to **nested database transactions** inside `register_contractor`: the handler opened a transaction and then called `register_user`, which opens **its own** transaction on the same connection.

A small structural change was applied in the backend so `register_user` is no longer nested inside an outer `conn.transaction()` in `register_contractor`.

**Please review, restart the API process so the change is loaded, and confirm register returns 201 (or a proper 4xx) instead of 500.**

### Problem

#### Symptom

```http
POST /v1/contractors/register
Content-Type: application/json

{
  "full_name": "Probe User",
  "email": "probe@example.com",
  "password": "Contractor1!",
  "terms_version": "v0.1-placeholder",
  "privacy_version": "v0.1-placeholder"
}
```

**Observed:** `500 Internal Server Error` with body `Internal Server Error` (no structured `detail`).

**Expected:**

| Outcome | Status | Notes |
|---------|--------|--------|
| Success | `201` | `{ contractor_id, user_id, email }` — **no tokens** |
| Bad / unknown legal version | `4xx` | e.g. `legal_document_unavailable` |
| Email already registered | `409` | |
| Hard-split (tenant member) | `409` | `hard_split_violation` |
| Validation | `422` | password rules, missing fields |

Opaque 500s block Flutter dogfood of S1 (register → login).

#### Root cause (suspected / addressed)

**Before (nested transactions):**

```text
register_contractor:
  async with conn.transaction():          ← outer txn
      register_user(...):
          async with conn.transaction():  ← nested txn / savepoint
              INSERT auth.users
              INSERT auth.user_credentials
          log_security_event(...)
      INSERT workforce.contractors
      compliance legal_events (accepted ×2)
```

`register_user` (in `app/modules/auth/service.py`) always starts its own `async with conn.transaction()`. Calling it **inside** another open transaction on the same `asyncpg` connection is fragile: depending on runtime/driver behaviour, later steps (contractor insert / legal events / rollback on `HTTPException`) can surface as an unhandled error → FastAPI **500** with no useful client `detail`.

This is separate from (but often confused with):

- Missing seeded legal docs (`platform_terms` / `privacy_policy` versions)
- Wrong `terms_version` / `privacy_version` (should be **4xx**, not 500)
- `counsel_pending` fail-closed in **production** only

Those should remain proper HTTP errors after the transaction structure is sound.

### Change made

**File:** `app/modules/contractors/service.py`  
**Function:** `register_contractor`

**After (un-nested):**

```text
register_contractor:
  # hard-split checks (unchanged)
  register_user(...)                      ← owns its own transaction
  async with conn.transaction():          ← contractor + legal only
      INSERT workforce.contractors
      compliance legal_events (accepted ×2)
  return ContractorRegisterResponse
```

#### Behavioural notes / trade-off

| Topic | Detail |
|-------|--------|
| What improved | Avoids nested txn around `register_user`; clearer failure modes for contractor/legal steps |
| Atomicity | Auth user creation and contractor+legal are **no longer one atomic transaction**. If contractor/legal fails **after** `register_user` succeeds, an auth user may exist without a contractor row |
| Follow-up (recommended) | On failure after user create: compensate (delete user / mark incomplete) **or** refactor so user+contractor+legal share a **single** transaction without `register_user` opening a nested one (e.g. internal helper that inserts without starting its own txn) |
| API contract | Unchanged: same request/response schema for `POST /v1/contractors/register` |

No OpenAPI / route / schema changes were made. Rate limit (`5/minute`) and body fields are unchanged.

### Flutter / local env expectations (for verification)

Flutter S1 sends:

- `terms_version` / `privacy_version` from dart-defines (local defaults: **`v0.1-placeholder`**, matching `timesheet-db` seed `011_compliance_policy_placeholders.sql`)
- Bundled markdown is display-only until a public legal-read endpoint exists

Ensure DB has current, non-retired versions for:

- `doc_key = platform_terms`
- `doc_key = privacy_policy`

If versions are missing, the API should return a **structured 4xx**, not 500.

### Verification checklist (API)

1. **Restart** the backend process so `service.py` is loaded (debug sessions often do not hot-reload this).
2. Confirm legal rows exist (or seed them).
3. Call register with a fresh email and matching versions → expect **201**.
4. Call again with same email → expect **409**.
5. Call with unknown `terms_version` → expect **4xx** with a clear `detail` / code (not 500).
6. Optionally re-run existing contractor register tests:
   - `tests/contractors/test_register_legal.py`
   - smoke tests that call `/v1/contractors/register`

### Requested API review

Please confirm:

1. The un-nested structure is acceptable for V1, **or** propose a single-transaction refactor without nested `register_user`.
2. Whether compensation is required if contractor/legal fails after user insert.
3. That local seed versions (`v0.1-placeholder`) are the intended dogfood versions (or publish the canonical versions Flutter should send via `TERMS_VERSION` / `PRIVACY_VERSION`).

### Related Flutter docs

- [implementation-checklist.md](./implementation-checklist.md) — S1
- [domain-v2-flag.md](./domain-v2-flag.md) — dart-defines for legal versions
- [manual-qa-s0-s1.md](./manual-qa-s0-s1.md) — manual test steps
- Design §6.2 — contractor register contract (no tokens on success)

---

## Template for new issues

Copy below when Flutter needs another backend change:

```markdown
## BH-00N — <short title>

**Date:** YYYY-MM-DD  
**Status:** Open | Proposed change applied | Waiting on API | Done  
**Related Flutter slice:** Sx  
**Endpoint / area:**  

### Problem
(symptom, expected vs actual, how Flutter is blocked)

### Proposed or applied change
(file, behaviour, API contract impact)

### Verification
(steps / curl / tests)

### Requested from API
(decision / merge / seed / docs)
```
