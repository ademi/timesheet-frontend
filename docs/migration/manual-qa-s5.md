# Manual QA — S5 Clients CRM

**Depends on:** S0 (staff shell)  
**Backend follow-ups:** [BH-005](./backend-handoff-contractor-register-nested-txn.md), [BH-006](./backend-handoff-contractor-register-nested-txn.md), [BH-007](./backend-handoff-contractor-register-nested-txn.md)

---

## 0. Prerequisites

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=DOMAIN_V2=true
```

| Role | Credential |
|------|------------|
| Staff | `admin@demotenant.example` / `ChangeMe123!` |
| Public | No login — invite acknowledge |

Staff JWT needs `clients.read` / `clients.manage` (demo admin should have them).

---

## S5-1 Clients list / create

- [ ] Staff → **Clients** (`/staff/clients`) loads `GET /v1/clients`.
- [ ] **Add client** → full name required; optional email/phone/notes; status active/inactive.
- [ ] Create → `POST /v1/clients` **201**; appears in list.

---

## S5-2 Detail tabs — sites

- [ ] Open client → Sites / Contacts / Invites chips.
- [ ] **Add site** — name + **latitude + longitude required** (Flutter validation).
- [ ] Optional address fields + geofence radius (10–5000) + primary toggle.
- [ ] Create → `POST /v1/clients/{id}/sites` **201**; list shows coords.
- [ ] Edit / delete site works (`PATCH` / `DELETE`).
- [ ] Note: API may still accept sites without coords (BH-006) — Flutter must not.

---

## S5-3 Contacts

- [ ] Add contact with name and/or email and/or phone.
- [ ] Primary + notify-on-visit-complete toggles.
- [ ] Create / edit / delete → matching contact endpoints.

---

## S5-4 Invite token

- [ ] Invites tab → **Create invite token** → `POST /v1/clients/{id}/invites` **201**.
- [ ] UI shows Flutter path `/invites/client/{token}` and notes legacy `/invite/{token}` (BH-005).
- [ ] Copy path works.
- [ ] No historical invite list yet (BH-007) — only last created in session.

---

## S5-5 Public acknowledge

- [ ] Open `/invites/client/<token>` (logged out OK).
- [ ] Loads `GET /v1/public/client-invites/{token}` — tenant name + client first name + expiry.
- [ ] **Acknowledge** → `POST .../acknowledge` `{ "accept": true }` → success message; `consent_acknowledged` true on reload.
- [ ] Also verify `/invite/<token>` alias opens the same screen (email path).

---

## Exit

Staff can CRUD clients/sites/contacts, mint an invite, and a recipient can acknowledge via the public route.
