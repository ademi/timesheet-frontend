# Flutter Migration Documentation

This folder contains the technical impact study and migration plan for aligning the **Rostiq Flutter app** (`timesheet-frontend`) with the new Contractor / Client / Job platform domain.

## Documents

| Document | Description |
|----------|-------------|
| [flutter-migration-impact-study.md](./flutter-migration-impact-study.md) | Full impact study (executive summary through final recommendations) |
| [mapping-table.md](./mapping-table.md) | Detailed old → new concept mapping table |
| [clarification-questions.md](./clarification-questions.md) | Backend/product questions grouped by domain |
| [development-backlog.md](./development-backlog.md) | Suggested task breakdown with priority and estimates |
| [implementation-checklist.md](./implementation-checklist.md) | Phase-by-phase implementation checklist (start coding here) |

## Source inputs

| Input | Path |
|-------|------|
| New platform design spec | [`docs/2026-07-22-contractor-client-job-design (1).md`](../2026-07-22-contractor-client-job-design%20(1).md) |
| Current Flutter app | `lib/` (GetX + Dio layered architecture) |

## How to use

1. Stakeholders: start with **Executive Summary** in the impact study.
2. Engineering: use **Gap Analysis**, **Mapping Table**, and **Required Flutter Changes**.
3. Product/Backend: answers live in **Clarification Questions** (answer log filled 2026-07-23).
4. Planning: use **Migration Plan**, **Effort**, and **Development Backlog**.
5. Implementation: work through **[implementation-checklist.md](./implementation-checklist.md)** phase checkboxes.

## Status

| Item | Status |
|------|--------|
| Codebase inventory | Complete (as of 2026-07-23) |
| Spec review | Complete (design doc dated 2026-07-22) |
| Backend clarification answers | Complete (answer log in clarification-questions.md) |
| Implementation checklist | Ready — start at Phase 1 exit / Phase 2 |
| UX wireframes for contractor app | **Pending** (product; API supports dual-shell) |

---

*Generated for the Rostiq Flutter migration program. Do not treat endpoint paths in the design spec as final until confirmed against the backend OpenAPI.*
