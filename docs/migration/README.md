# Flutter Migration Documentation

**Authoritative Flutter build spec (2026-07-23):**  
→ [2026-07-23-frontend-contractor-domain-restructure-design.md](./2026-07-23-frontend-contractor-domain-restructure-design.md)

**Reconciliation vs older Phase 1–2 corpus:**  
→ [design-delta-2026-07-26.md](./design-delta-2026-07-26.md)

**Day-to-day checklist (slices S0–S10):**  
→ [implementation-checklist.md](./implementation-checklist.md)

---

## Documents

| Document | Role |
|----------|------|
| [2026-07-23-frontend-contractor-domain-restructure-design.md](./2026-07-23-frontend-contractor-domain-restructure-design.md) | **Source of truth** for Flutter IA, folders, slices, compliance rules |
| [design-delta-2026-07-26.md](./design-delta-2026-07-26.md) | What changed vs prior migration docs |
| [implementation-checklist.md](./implementation-checklist.md) | S0–S10 checkboxes |
| [frontend-api-wiring-guide.md](./frontend-api-wiring-guide.md) | API shapes helper (verify vs live routers) |
| [domain-v2-flag.md](./domain-v2-flag.md) | Dart-defines + cutover wipe |
| [phase1/](./phase1/) | Discovery archive (OpenAPI, scope, errors, permissions, redirect) — **updated 2026-07-26** |
| [clarification-questions.md](./clarification-questions.md) | Backend/product Q&A log |
| [flutter-migration-impact-study.md](./flutter-migration-impact-study.md) | Earlier impact study (historical; prefer restructure design for coding) |
| [mapping-table.md](./mapping-table.md) | Old → new concept mapping (historical) |
| [development-backlog.md](./development-backlog.md) | Backlog aligned to S0–S10 |

## How to use

1. Read the **Flutter restructure design** end-to-end (§0–§9).
2. Skim **design-delta** so prior Phase 2 assumptions are not reused blindly.
3. Implement via **implementation-checklist** slices; keep app runnable each slice.
4. For JSON fields, use wiring guide + live `/docs` / `schemas.py`; do not invent endpoints.
5. Compliance copy rules in design §5 are non-negotiable.

## Status (2026-07-26)

| Item | Status |
|------|--------|
| Flutter restructure design ingested | **Done** — docs reconciled |
| Discovery (Phase 1 archive) | Complete |
| Prior Phase 2 prototype (`lib/app` stubs) | Partial S0 — **must realign** to `lib/features/` |
| Next implementation | **S0** skeleton (SessionService, Staff/Contractor shells, gateway) |
| Records-engine / in-app billing checkout | Out of V1 |

---

*Prefer the 2026-07-23 Flutter restructure design over older Phase 3+ wording when they conflict.*
