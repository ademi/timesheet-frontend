# Manual QA — S3 Credentials + documents

**Depends on:** S0–S2 ([manual-qa-s0-s1.md](./manual-qa-s0-s1.md), [manual-qa-s2.md](./manual-qa-s2.md))  
**API blockers:** [BH-002](./backend-handoff-contractor-register-nested-txn.md), [BH-003](./backend-handoff-contractor-register-nested-txn.md), **[BH-004](./backend-handoff-contractor-register-nested-txn.md)** (`credentials.read` / `credentials.manage` on pre-active engagements)

---

## 0. Prerequisites

### Flutter run

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=TERMS_VERSION=v0.1-placeholder \
  --dart-define=PRIVACY_VERSION=v0.1-placeholder \
  --dart-define=DOMAIN_V2=true
```

### Accounts

| Role | Credential | Notes |
|------|------------|-------|
| Staff | `admin@demotenant.example` / `ChangeMe123!` | Seed `002` — invite + review |
| Contractor | Create via S1 register | Must have engagement (BH-002); JWT needs compliance (BH-003) + credentials (BH-004) |

### Permission check (before dogfood)

Decode contractor JWT (or call `GET /v1/auth/me/context`) and confirm permissions include:

- `credentials.read`
- `credentials.manage`
- `documents.upload`

If missing → record **BH-004 fail** and stop contractor create/list steps.

---

## S3-1 Onboarding credentials step

- [ ] Complete S2 legal → notices → consents → engagement stub.
- [ ] Credentials step shows **Add credential** / **Refresh** (not the old stub copy).
- [ ] Presented notice event IDs from notices step are reused when creating (no extra “notice missing” if catalog notice exists for that type).

---

## S3-2 Create credential (allowlist + UX)

- [ ] Open **Add credential** (`/contractor/credentials/create`).
- [ ] Type dropdown is limited to the design allowlist (`passport_id`, `wwcc`, `police_check`, …).
- [ ] Sensitive type (e.g. `police_check`): consent checkbox required before Create.
- [ ] Government ID (`passport_id` / `drivers_licence`): proxy-download acknowledgement required.
- [ ] Create calls `POST /v1/contractor-me/credentials` with `notice_event_id` + `credential_type`.
- [ ] Success → appears on list with status / evidence / provenance metadata.

---

## S3-3 Evidence upload + scan poll

- [ ] From list or detail → **Attach evidence**.
- [ ] Pick PDF/PNG/JPEG.
- [ ] Network sequence:
  1. `POST /v1/documents/upload-url` (`owner_type=contractor`, `category=<credential_type>`)
  2. HTTP **PUT** to signed `upload_url` (no API Bearer required on PUT)
  3. `POST /v1/documents/{id}/finalize` body `{ "credential_id": "..." }`
  4. Poll `GET /v1/documents?owner_type=contractor&owner_id=...` until `scan_status` is `clean` or `blocked`
- [ ] UI shows last scan status.
- [ ] Blocked file shows fail messaging (re-upload); clean updates `evidence_presence`.

---

## S3-4 Contractor shell Credentials tab

- [ ] `/contractor/credentials` (bottom nav) lists credentials (not stub).
- [ ] Detail shows metadata; supersede available when manage permitted.
- [ ] Logout still works from list AppBar.

---

## S3-5 Download helper (signed vs proxy)

Unit / manual helper path (staff or contractor with a document id):

- [ ] Non-restricted: `GET .../download-url` → open signed URL.
- [ ] Restricted / government ID category: download-url returns `403` `proxy_required` → client uses `GET .../content` with Bearer (optional `X-Delivery-Id`).
- [ ] UI/snackbar indicates proxy path was used (does **not** claim a signed URL was viewed).

---

## S3-6 Staff credential review

- [ ] Staff → Compliance → **Open credential review** (`/staff/credentials-review`).
- [ ] Enter `contractorId` + `engagementId` → **Load credentials** (`GET /v1/tenants/current/contractors/{id}/credentials`) — metadata only.
- [ ] Review actions: Accept / Reject / Re-review → `POST /v1/engagements/{id}/credential-reviews`.
- [ ] If API returns `mfa_required`: MFA banner shown; decision not silently skipped.
- [ ] If API returns `eligibility_incomplete`: itemised panel lists reasons; copy does **not** say “NDIS certified” / “Verified by Rostiq”.

---

## S3-7 Negative / blockers

- [ ] Without BH-004: list/create shows clear missing-permission messaging (not a blank crash).
- [ ] Upload without `documents.upload` blocked with permission message.
- [ ] Create without collection notice for type → structured error (notice unavailable / not presented).

---

## Exit

S3 Flutter exit is met when upload → finalize → scan UI and proxy download helper are exercised against a live API (or recorded blocked by BH-004 with UI defensive handling).
