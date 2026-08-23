# NDIS Management Tools — Competitor Research & Gap Analysis vs Rostiq

**Date:** 2026-08-21  
**Revision:** 2026-08-23 — Phase C backend (T17–T19) shipped; priorities and locked decisions updated.  
**Research type:** Pricing + product gap / positioning  
**Note:** Rostiq (this product) is distinct from **Rostery** (rostery.com.au), a similarly named all-in-one competitor.

**Sources:** Public 2026 buyer guides ([FlowLogic list](https://flowlogic.com.au/blogs/best-ndis-software/), [AMBR](https://www.ambrit.com.au/blog/ndis-software-buyers-guide-australia)), competitor sites (ShiftCare, Tendaroo, Brevity, Rostery, Careview), and Rostiq codebase/specs.

---

## Revision log (2026-08-23)

**Shipped since initial research (backend only):**

| Slice | What landed | Competitor gap closed |
|-------|-------------|------------------------|
| Phase A | NDIS Support Catalogue import, strict validation on jobs/visits/tasks | Price guide lookup (partial) |
| Phase B | Invoice export CSV, `invoice_status`, participant NDIS number on lines | Revenue loop to plan manager (partial) |
| Phase C (T17) | MMM postcode → `national`/`remote`/`very_remote` price tier at export; staff override | Remote loadings on invoice lines (backend) |
| Phase C (T18) | Multi-line export per coded visit task + `billable_minutes` | Multi-NDIS-line shifts (backend) |
| Phase C (T19) | Void export + revert visits to re-export | Correction workflow (backend) |

**Locked decisions (Phase C — see [TODOS](TODOS.md#get-paid-loop-locked-decisions)):**

1. **Hybrid tier:** staff `price_tier_override` → MMM postcode → `national` default (unknown postcode does not block export).
2. **Task-coded visits:** export uses task lines only; visit-level support item stamp not required when tasks have codes.
3. **Task minutes:** explicit per task; sum ≤ clocked hours; under-assignment allowed.
4. **Void:** finalized exports only; no PRODA submission guard yet.
5. **No Flutter in Phase C** — coordinators still need T15 + T21 for glass.

**Revisioned priorities:**

| Before | After (2026-08-23) |
|--------|-------------------|
| P0 claiming = export + support items (mostly backend gap) | **P0 buyer risk is now Flutter** — T15 catalogue picker + export/void UI, T21 tier/minutes, T14 support item fields |
| T17–T19 listed as future P3 backend | **Done** — regional pricing + multi-line + void on API |
| Rec #1 “ship invoice export” = Med effort | Backend **done**; remaining effort is **staff UI + demo polish** (T15, T20) |

---

## Executive summary

Rostiq sits in a different wedge than most “NDIS management” suites: **contractor-owned credentials + GPS visit verification + provider ops**, not a full claim/care-plan OS. That is the clearest differentiator — and also why buyers will compare you against ShiftCare/Brevity/Tendaroo and ask “where is PRODA?”

**Top findings**

1. The market has consolidated around **all-in-one** (roster → note → invoice → PRODA/PACE claim).
2. Rostiq’s unique angle is a **portable contractor credential vault** with consent/sharing — rare among incumbents that treat docs as provider-owned HR files.
3. Biggest gaps vs category leaders: **NDIS claiming (PRODA), plan budgets, SCHADS award engine, Xero/MYOB, participant/family portals** — but **invoice export + catalogue + tiered pricing** are no longer pure gaps on the backend.

**Top recommendations (revised)**

1. Position as **workforce compliance + EVV for contractor-heavy NDIS providers**, not a Brevity replacement.
2. **Ship Flutter get-paid UX next** — [T15](TODOS.md#t15--flutter-ndis-catalogue-picker--invoice-export-ui) + [T21](TODOS.md#t21--flutter-visit-price-tier-override--task-billable-minutes) + [T14](TODOS.md#t14--flutter-ui-for-visit--job-support-item) — backend loop is ready.
3. Productise care-plan-per-shift + NDIS number for demos ([T20](TODOS.md#t20--shift-care-plan-tasks--participant-ndis-number-demo-parity)).

---

## Competitors identified

| Competitor | Category | Position | Key strength |
|---|---|---|---|
| [ShiftCare](https://shiftcare.com) | All-in-one SMB–mid | Best-known value play | GPS clock, notes, invoicing; PRODA on Premium; from ~$9/user |
| [FlowLogic](https://flowlogic.com.au) | Enterprise ops + compliance | Mid–large / multi-funding | ISO 27001, deep governance, NDIS + Aged Care |
| [Lumary](https://www.lumary.com) | Enterprise (Salesforce) | Large multi-program | AI rostering, portal automation |
| [SupportAbility](https://www.supportability.com.au) | Enterprise compliance | Multi-site registered providers | Audit/compliance depth |
| [Brevity](https://www.brevity.com.au) | Mid-market all-in-one | Small–mid providers | NDIS-native UX; per-client pricing |
| [CareMaster](https://www.caremaster.com.au) | AU all-in-one | Small–mid | Local support, NDIA submission |
| [Tendaroo](https://tendaroo.com) | Modern all-in-one | Fast setup, AU data | Public participant pricing; offline worker app |
| [RotaWiz](https://www.rotawiz.com.au) | Rostering specialist | Roster-first buyers | SCHADS-aware scheduling + GPS |
| [GoodHuman](https://www.goodhuman.me) | CRM + billing + roster | Participant experience | Digital service agreements drive automation |
| [Careview](https://www.careviewapp.com) / [Entiprius](https://entiprius.com.au) | **Plan management** | Plan managers / SC | PRODA/PACE APIs, budget/invoice automation |
| [Rostery](https://rostery.com.au) | Full suite + EVV | Aggressive “complete platform” | GPS EVV, SCHADS payroll, PRODA, eMAR, AI |
| Imploy / Vertex360 | Entry / mid | Price-sensitive | Free/low entry tiers |

**Market note:** Plan-manager tools (Careview, Entiprius) are adjacent, not direct peers, unless Rostiq expands into plan management.

---

## Rostiq today (from product/code)

### Shipped / in build

- Multi-tenant providers + **contractor** actors
- **Credential vault** (NDIS worker screening, WWCC, police check, etc.) with reviews, eligibility gates, sharing grants, collection notices, consent
- Clients/sites, jobs/visits, **geofenced GPS check-in/complete** (PostGIS)
- Shift roster (release / claim / multi-worker)
- Form templates (progress notes, reportable-incident style NDIS forms)
- Compliance ops (legal events, rights, incidents, audit)
- Engagement rate bands (base / evening / night / weekend / PH) → payment batches
- Flutter web + mobile
- **NDIS Support Catalogue** (import, active release, search API) — Phase A
- **Support item stamps** on jobs/visits/tasks with catalogue validation — Phase A + V027
- **Invoice export CSV** (hourly lines, participant NDIS number, `invoice_status`) — Phase B
- **MMM price tier** at export (national/remote/very_remote + staff override) — Phase C / T17
- **Multi-line export** from coded visit tasks + `billable_minutes` — Phase C / T18
- **Void export** + revert visit `invoice_status` — Phase C / T19

### Explicitly deferred / missing vs full NDIS suites

- Records engine / client onboarding packs
- **PRODA/PACE claiming** (export to plan manager is shipped; direct NDIA submit not)
- Full SCHADS award interpretation (rate *bands*, not award rules)
- Accounting integrations (Xero/MYOB)
- Care plans / goals / plan budget utilisation — shift tasks + NDIS number demo parity on [TODOS T20](TODOS.md#t20--shift-care-plan-tasks--participant-ndis-number-demo-parity); full plan budgets still out of scope
- **Flutter** for catalogue picker, export/void UI, tier override, task minutes ([T15](TODOS.md#t15--flutter-ndis-catalogue-picker--invoice-export-ui), [T21](TODOS.md#t21--flutter-visit-price-tier-override--task-billable-minutes), [T14](TODOS.md#t14--flutter-ui-for-visit--job-support-item))
- Scheduled catalogue refresh ([T16](TODOS.md#t16--scheduled-ndis-catalogue-refresh))

---

## Product comparison (gap matrix)

| Capability | Rostiq | Typical leaders (ShiftCare, Brevity, Tendaroo, FlowLogic, Rostery) |
|---|---|---|
| GPS / EVV clock-in | Strong (geofence modes) | Common |
| Rostering / open shifts | Strong & building | Table stakes |
| Progress notes / forms | Present (templates) | Mature + templates library |
| Worker screening docs | **Differentiated** (contractor-owned vault + consent) | Usually provider document store |
| Cross-provider credential portability | **Standout** | Rare / absent |
| Privacy/APP legal workflow | **Standout** (notices, grants, rights) | Basic upload + expiry |
| NDIS price guide → invoice | **Partial (backend)** — catalogue, export, tier, multi-line; **no staff UI yet** | Core |
| PRODA / PACE claims | Gap | Core for “management” buyers |
| Plan budget / fund tracking | Gap | Core |
| SCHADS award engine | Partial (manual bands) | Strong on mid/enterprise |
| Xero / MYOB | Gap | Common |
| Participant / family portal | Gap | Differentiator for GoodHuman/Rostery |
| eMAR / clinical SIL | Gap | Niche (Rostery, Visibility-class) |
| Aged Care dual funding | Gap | FlowLogic / AlayaCare |
| AI rostering / notes | Gap | Lumary, ShiftCare, Imploy |

---

## What makes Rostiq stand out

1. **Contractor-centric model** — providers engage contractors; credentials live in a **global vault**, shared under authorisation — not re-uploaded per agency.
2. **Compliance-by-design for screening** — NDIS worker screening notices, sensitive consent, sharing grants, eligibility blocking shift claim — closer to regulated workforce ops than “upload PDF and forget.”
3. **GPS visit verification tied to jobs/clients** — same EVV story competitors sell, with PostGIS geofencing already in the stack.
4. **Cleaner wedge for contractor-heavy / labour-hire / allied-health subcontract models** — where incumbents assume employed carers and SCHADS payroll as the centre of gravity.
5. **Privacy posture as a product feature** — rights requests, access history, incident handling, “don’t claim NDIS certification” copy discipline — useful vs vendors that over-claim “Commission compliant.”
6. **Backend get-paid loop** (2026-08-23) — catalogue-validated support lines, tier-aware invoice export, multi-line tasks, void/re-export — rare depth for a contractor-first product **before** PRODA.

---

## What Rostiq misses (priority gaps)

### P0 — buyers will churn without these

| Gap | Why it matters | Competitor benchmark | Rostiq status |
|---|---|---|---|
| **NDIS claiming path** (CSV/PRODA or plan-manager invoice export) | “Management tool” = get paid | ShiftCare Premium, Brevity, Tendaroo, Rostery | **Backend: export + void shipped.** **Flutter: T15** |
| **Price guide / support item codes on visits** | Audit + billing accuracy | Almost all all-in-ones | **Backend: catalogue + stamps shipped.** **Flutter: T14, T15** |
| **Participant plan / funding visibility** | Coordinators live in budgets | ShiftCare, SupportAbility, GoodHuman | Still gap |

### P1 — parity for mid-market RFPs

| Gap | Why | Benchmark | Rostiq status |
|---|---|---|---|
| SCHADS (or clear “contractor rates only” positioning) | Employed workforce RFPs | FlowLogic, Rostery, ShiftCare Premium | Partial |
| Xero/MYOB | Finance teams expect it | Brevity, ShiftCare | Gap |
| Care plans / goals / task lists per shift | [TODOS T20](TODOS.md#t20--shift-care-plan-tasks--participant-ndis-number-demo-parity) | GoodHuman, CareMaster | Backend tasks exist; demo UX gap |
| Offline field app | Regional delivery | Tendaroo, ShiftCare | Gap |
| Incident → reportable timeframe workflows | Commission audits | Mature suites | Gap |
| **Regional price tier UX** | Remote providers need correct limits | Category standard | **Backend T17 shipped; Flutter T21** |
| **Multi-NDIS-line shifts** | One visit, multiple billable codes | Mature suites | **Backend T18 shipped; Flutter T21 + T15** |

### P2 — expansion / enterprise

- Multi-entity consolidated reporting
- Family/nominee portal
- AI note assist / smart matching
- ISO 27001 marketing credential
- Aged Care / multi-scheme
- Automated catalogue refresh ([T16](TODOS.md#t16--scheduled-ndis-catalogue-refresh))

---

## SWOT (Rostiq)

| | |
|---|---|
| **Strengths** | Portable credentials; consent/sharing; GPS EVV; contractor + staff dual shell; engagement eligibility; **tier-aware invoice export API** |
| **Weaknesses** | **No coordinator UI for billing yet**; thin NDIS clinical/care-plan layer; low public brand vs ShiftCare/Brevity |
| **Opportunities** | Own “contractor marketplace compliance”; integrate *out* to plan managers instead of building full PRODA; ship Flutter billing UX to unlock rec #1 narrative |
| **Threats** | Rostery/ShiftCare adding stronger credential vaults; name confusion with **Rostery**; buyers defaulting to all-in-one even if vault is superior |

---

## Positioning recommendation

**Do not** compete as “another ShiftCare.”  
**Do** compete as:

> *Rostiq — NDIS workforce & visit verification for providers who run on contractors: portable screening credentials, GPS-proofed visits, roster-to-pay — with billing/claiming via export or integrations.*

**Messaging that works now**

- Portable NDIS worker screening / WWCC vault
- Geofenced proof of delivery
- Eligibility-gated shift claim
- **API-ready invoice export** with catalogue validation, remote tier pricing, and multi-line task billing *(add “in app” once T15 ships)*

**Messaging that fails until built**

- “All-in-one NDIS management” (no Flutter billing UX yet)
- “PRODA-ready” / “end-to-end claiming”

---

## Prioritized recommendations

| # | Recommendation | Impact | Effort | Backlog | Status (2026-08-23) |
|---|---|---|---|---|---|
| 1 | Ship **invoice/timesheet export** to worker + plan manager | Unlocks revenue story | Med → **Low (UI only)** | [T15](TODOS.md#t15--flutter-ndis-catalogue-picker--invoice-export-ui) + [T21](TODOS.md#t21--flutter-visit-price-tier-override--task-billable-minutes) | **Backend done** |
| 2 | Bind visits to **support item / NDIS line** (even without live PRODA) | Sales + audit | Med → **Low (UI only)** | [T14](TODOS.md#t14--flutter-ui-for-visit--job-support-item) | **Backend done** |
| 3 | **Care plan / tasks per shift** + participant NDIS number as first-class facts | Demo parity | Med | [T20](TODOS.md#t20--shift-care-plan-tasks--participant-ndis-number-demo-parity) | Open |
| 4 | Publish positioning + **alternatives** content vs ShiftCare/Brevity/Rostery (credential portability angle) | SEO/demand | Low | — | Open |
| 5 | Decide: build PRODA vs partner with Careview/Entiprius-class PM tools | Strategy | High | — | Open |
| 6 | Explicit “contractor rates vs SCHADS employees” ICP filter | Avoid bad-fit churn | Low | — | Open |

---

## Follow-ups (optional)

- One-page **sales battlecard** (ShiftCare / Brevity / Rostery) — update with “export API shipped, UI next”
- **Roadmap backlog** ranked by ICP — see [TODOS.md](TODOS.md) (T14–T21 NDIS slice; T17–T19 backend complete)
