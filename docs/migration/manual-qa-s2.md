# Manual QA — S2 Compliance legal + onboarding funnel

**Depends on:** S0 + S1 ([manual-qa-s0-s1.md](./manual-qa-s0-s1.md))  
**API blockers:** [BH-002](./backend-handoff-contractor-register-nested-txn.md), [BH-003](./backend-handoff-contractor-register-nested-txn.md)

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


| Role       | Credential                                  | Notes                                               |
| ---------- | ------------------------------------------- | --------------------------------------------------- |
| Staff      | `admin@demotenant.example` / `ChangeMe123!` | Seed `002` — invite engagement                      |
| Contractor | Create via S1 register                      | Unique email each run; password e.g. `Contractor1!` |




### Recommended dogfood path (until BH-002 / BH-003 land)

1. **Staff** logs in → (later S4 will have invite UI). Until then, create engagement via API/Swagger:
  - Login as staff → copy `access_token`
  - `POST /v1/tenants/current/engagements` with body `{ "email": "<contractor_email>", "required_categories": ["wwcc"] }` (adjust categories as allowed by API)
2. **Contractor** logs in (must have engagement — BH-002).
3. JWT must include `compliance.legal.read` + `compliance.legal.accept` while `invited`/`pending_docs` (BH-003). If missing, legal step shows permission error — record fail + stop.



### Quick invite curl (after staff login)

```bash
# 1) Staff login — use identifier (not email)
curl -X POST http://localhost:8000/v1/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"identifier\":\"admin@demotenant.example\",\"password\":\"ChangeMe123!\"}"

# 2) Invite (paste access_token)
curl -X POST http://localhost:8000/v1/tenants/current/engagements ^
  -H "Authorization: Bearer <STAFF_ACCESS_TOKEN>" ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"contractor.qa+s2@example.com\",\"required_categories\":[\"wwcc\",\"police_check\"]}"
```

---



## S2-1 Entry into onboarding (outside tab chrome)

- [x] Log in as **contractor** (after invite).
- [x] Lands on `/contractor/onboarding/legal` (or `/contractor/onboarding` which redirects there).
- [x] **No** contractor bottom-nav / rail (onboarding is outside shell).
- [x] Progress header shows steps: Legal → Notices → Consents → Engagement → Credentials.
- [x] Logout icon works → Gateway.

---



## S2-2 Legal step (cannot skip)

- [x] App fetches live docs: `platform_terms` and `privacy_policy` (Network: `GET .../legal-documents/current?doc_key=`).
- [x] Each doc shows markdown (read-only) + version + separate **Accept** control.
- [x] Counsel-pending banner may appear for seed placeholders — OK in development.
- [x] **Continue** blocked until **both** docs accepted (snackbar if skipped).
- [x] Accept fires `presented` then `accepted` legal-events (or presented on load + accepted on tap).
- [x] Retries reuse **Idempotency-Key** (same key on repeat accept for same doc/version).
- [x] If API returns counsel unavailable / missing permission → error banner; cannot fake-advance without Accept succeeding.

---



## S2-3 Notices step

- [ ] After legal Continue → Notices step loads `GET .../collection-notices`.
- [ ] Each notice has separate acknowledge (not one mega-checkbox).
- [ ] Continue blocked until all listed notices acknowledged (or empty list → Continue allowed).
- [ ] Network: `event_type=acknowledged` with `notice_key` / `notice_version`.

---



## S2-4 Consents step

- [ ] Sensitive types that appear on notices (e.g. `police_check`) require checkbox/consent action.
- [ ] If no sensitive notices → message that consents can wait until S3; Continue allowed.
- [ ] Network: `event_type=consented` with `credential_type` (and notice keys when present).
- [ ] Cannot Continue while required consents unchecked.

---



## S2-5 Stub steps + finish

- [ ] Engagement step is a **stub** (S4) — Continue allowed.
- [ ] Credentials step is a **stub** (S3) — **Finish** → `/contractor/home` with shell chrome.
- [ ] Re-login after Finish: if engagement is `active` and funnel marked done → Home; if still `invited`/`pending_docs` → may return to onboarding (expected until engagement progresses).

---



## S2-6 Negative / guard checks

- [ ] Staff JWT cannot open `/contractor/onboarding/legal` → Wrong actor.
- [ ] Unauthenticated deep link → Gateway.
- [ ] Back button does not skip ahead of incomplete accepts (re-entering a step keeps progress).

---



## Pass criteria


| Check                                            | Pass? |
| ------------------------------------------------ | ----- |
| Onboarding outside tab chrome                    |       |
| Legal presented→accepted separately; cannot skip |       |
| Notices acknowledged separately                  |       |
| Consents for sensitive notice types              |       |
| Finish → contractor home                         |       |
| Idempotency-Key present on legal-event POSTs     |       |


---



## Results log


| Date | Tester | S2                    | BH-002/003 status | Notes |
| ---- | ------ | --------------------- | ----------------- | ----- |
|      |        | Pass / Fail / Blocked |                   |       |


