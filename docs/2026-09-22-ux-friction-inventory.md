# UX friction inventory — client docs & forms (+ web navigation)

**Audience:** Engineers picking up upload / form UX work, or web refresh / back-forward navigation  
**Date:** 2026-09-22  
**Scope:** Flutter frontend (`frontend/lib/`), especially client onboarding, care plan, requirements, credentials, contractor profile; plus browser history / deep-link restore on web  
**Trigger:** Care-plan clinical documents upload to the server on every file pick; that felt slow and high-friction. This doc inventories that pattern and related frictions found by code inspection. **Also added:** web refresh / back / forward throwing users out of workflows (GetX URL vs in-memory state).

**Not in scope:** Landing/marketing, visits roster confirms (mostly justified), billing void confirms.

---

## Problem statement

Several flows treat **“user chose a file”** as **“commit to the server now”**. When a step has multiple files (clinical PDFs, legal pack, credential evidence), the user waits on a network round trip after each Choose/Replace, often with the rest of the form frozen.

A better default (already used in parts of the app) is:

1. Pick → hold locally (`pending` / `localFiles`)
2. Upload on **Save / Next / Submit**
3. Keep sibling fields editable while one upload runs (or show row-level progress only)

---

## Shared building blocks

| Piece | Path | Notes |
|-------|------|--------|
| `AppFileField` | `frontend/lib/shared/widgets/app_file_field.dart` | Chrome only. Does **not** upload. Parent wires `onPick`. |
| `ProfilePhotoEditor` | `frontend/lib/shared/widgets/profile_photo_editor.dart` | Picks image → `onChanged(PickedProfilePhoto)`. Parent decides timing. |
| `ClientLegalUploadHelper` | `frontend/lib/features/clients/services/client_legal_upload_helper.dart` | Shared **pick → upload immediately** for consent / SA / ack / legal-other. |
| `DocumentPipeline.uploadEvidence` | `frontend/lib/features/documents/data/document_pipeline.dart` | Upload (+ optional scan poll for credentials). |
| `RequirementDraft.localFiles` | `frontend/lib/features/clients/controllers/requirement_draft.dart` | Deferred multi-file hold pattern (good reference). |

---

## A. Upload on pick (primary friction)

These call sites start a server request as soon as the user finishes the file picker.

### A1. Care plan — clinical documents (canonical example) — ✅ Done (2026-10-04)

| | |
|--|--|
| **UI** | `frontend/lib/features/clients/widgets/support_plan_clinical_section.dart` |
| **Store** | `SupportPlanClinicalStore` — `pickMedicalPdf` / `pickBspPdf` / `pickNutritionPdf` / `pickHazardPdf` → pending → upload in `persistFacts` |
| **Also shown in** | Onboarding care-plan step, support-plan review step |
| **Files** | 4 separate single-PDF slots |
| **Flow (fixed)** | Choose/Replace → hold locally (`pending*`) → upload + upsert on **Save draft / Activate**; row-level `isUploading*`; toggles independent until Save (B3) |
| **Was** | Pick → immediate `uploadEvidence` + `isBusy` froze sticky nav (B1) |

### A2. Care plan — NDIS plan PDF (funding) — ✅ Done (2026-10-04)

| | |
|--|--|
| **UI** | `support_plan_funding_section.dart` — `onPick: store.pickNdisPlanPdf` |
| **Store** | `SupportPlanFundingConsentStore.pickNdisPlanPdf` → `ndisPdfPending` → upload in `persistFacts` |
| **Files** | 1 PDF |
| **Flow (fixed)** | Pick → pending → upload + upsert NDIS fact with `documentId` on Save (aligned with onboarding) |
| **Was** | Pick → immediate upload under store `isBusy` |

### A3. Care plan — consent & agreements — ✅ Done (2026-10-04)

| | |
|--|--|
| **UI** | `support_plan_consent_section.dart` |
| **Store** | `markConsentComplete` / `markServiceAgreementComplete` / `markAcknowledgementComplete` with row `*Uploading` (not global `isBusy`) |
| **Helper** | `ClientLegalUploadHelper` — perms + consent legal version **before** pick |
| **Files** | Up to 3 PDFs (consent, service agreement, acknowledgement) |
| **Flow** | Pick → upload → accept/upsert → row flips Complete (standalone mark-complete kept) |
| **Helper copy** | “Upload PDF & mark complete” |

### A4. Onboarding — legal pack — ✅ Done (2026-10-04)

| | |
|--|--|
| **UI** | `onboarding_legal_pack_step.dart` |
| **Controller** | Row `*Uploading`; Finish gated on `isLegalUploading`; legal-other validates label before pick |
| **Files** | Consent + SA + optional Ack + **N dynamic “other” rows** (1 PDF each) |
| **Flow** | Same as A3; legal-other also persists the list fact immediately after each row upload |
| **Was** | Finish could race in-flight uploads; legal-other opened picker before label validation |

### A5. Contractor credentials — create evidence — ✅ Done (2026-10-04)

| | |
|--|--|
| **UI** | `credential_create_view.dart` |
| **Controller** | `CredentialsController.uploadEvidenceForCreate` |
| **Files** | 1 per click; multiple evidence docs accumulate as `selectedEvidence` |
| **Flow (fixed)** | Pick → upload → add chip immediately → **background** scan poll; Create gated on `hasCleanEvidenceReady` |
| **Related** | B2 |

### A6. Contractor credentials — attach to existing — ✅ Done (2026-10-04)

| | |
|--|--|
| **UI** | `credential_detail_view.dart`, also credentials list |
| **Controller** | `CredentialsController.attachEvidence` uses `isUploadingEvidence` (not `isSaving` through poll) |
| **Flow (fixed)** | Pick → upload → background scan poll → reload |

### A7. Contractor profile photo — ✅ Done (2026-10-04)

| | |
|--|--|
| **UI** | `contractor_profile_ops_view.dart` — `ProfilePhotoEditor(onChanged: controller.onPhotoPicked)` |
| **Controller** | `onPhotoPicked` / `clearPendingPhoto` hold locally → `_persistPhoto` inside `saveProfile` |
| **Flow (fixed)** | Pick/clear locally; upload or clear on **Save profile** (matches client form / onboarding) |
| **Was** | Immediate `uploadEvidence` + `setContractorProfilePhoto` on pick |

---

## B. Related frictions (not only “upload on pick”)

### B1. Global `isBusy` freezes care-plan chrome — ✅ Done (2026-10-04)

**Why it hurt:** One clinical/NDIS/consent PDF upload sets store `isBusy`. `SupportPlanController.isBusy` ORs funding + clinical busy with save/load. Sticky Back / Save draft / Next (and funding sibling fields) disable for the whole wait.

| Piece | Path |
|-------|------|
| Clinical busy | ~~`uploadClinicalPdf`~~ — picks no longer set `isBusy`; row `isUploading*` during Save |
| Funding NDIS | ~~`uploadNdisPlanPdf`~~ — picks no longer set `isBusy`; `isUploadingNdisPdf` during Save |
| Funding/consent busy | Legal mark-complete uses row `*Uploading` only (no global `isBusy`) |
| Aggregated | `support_plan_controller.dart` → `isBusy` (save/load only for these uploads) |
| UI gates | Sticky no longer freezes on clinical / NDIS / legal PDF uploads |

### B2. Credential scan poll blocks the form (~60s) — ✅ Done (2026-10-04)

**Why it hurt:** `uploadEvidenceForCreate` / `attachEvidence` held `isSaving` through `DocumentPipeline.pollScanStatus` (≈ 2s × 30).

**Fix:** Upload under `isUploadingEvidence` only; add evidence chip immediately; poll in background; Create gated on `hasCleanEvidenceReady` (all evidence clean).

### B3. Clinical upload vs toggle Save split — ✅ Done (2026-10-04)

**Why it hurt:** Immediate upload flipped BSP/nutrition/hazard switches locally while bool facts only persisted on Save draft / Activate.

**Fix:** Pick never flips toggles. PDFs and bool flags both commit in `persistFacts` on Save draft / Activate. Helper copy notes PDF uploads apply on Save.

### B4. Late permission / legal-version checks — ✅ Done for P0/P1 surfaces (2026-10-04)

**Why it hurt:** Clinical / NDIS / legal helper often called `_canUploadDocs()` (and consent legal version) **after** the file picker.

**Fix:** Clinical/NDIS/legal helper check permission (and consent legal version) **before** pick; care-plan UI disables Choose when `!canUploadDocs`; legal-other validates label before pick.

### B5. Onboarding Next = mandatory network persist — ✅ Product decision: KEEP (2026-10-04)

**Why it exists:** `ClientOnboardingController.nextStep` → `submitIdentity` / `submitAddress` / … each round-trips before advancing. Supports resume (`onboarding_incomplete`, URL `?id=` / `?step=`).

**Decision:** Keep resume-safe step persists. A local-draft-only wizard would break refresh/resume unless a large draft store is added. File picks remain deferred until each step submit.

### B6. Contacts one round trip per Add — ✅ Partial (2026-10-04)

**Why it hurt:** `saveContactDraft` → `createContact` / `patchContact` per contact used global `isSaving`, freezing sticky Back/Next.

**Fix:** Contact saves use `isSavingContact` (row-level). Sticky nav stays usable during Add/Save contact. Full local-draft batch-on-Next deferred (high risk; needs product OK for delayed server presence).

### B7. Serial cascades under one spinner

| Flow | Behavior |
|------|----------|
| Identity Next | Photo + up to 5 identity cards uploaded sequentially under one `isSaving` |
| Profile & docs Save | `_saveDynamicAnswers` serial per requirement + progress string |

**Direction:** Parallelize safe uploads (`Future.wait`) or show per-item progress without locking unrelated chrome.

### B8. Reload can wipe in-progress care-plan edits

| Trigger | Effect |
|---------|--------|
| Clinical/funding conflict or `_persist` failure | `reload` → `applyProfileBundle` |
| SN import (`support_plan_sn_section.dart`) | Confirm then `planController.load()` full reload |
| Discard on step 0 | Intentional `load()` |

**Direction:** Preserve dirty draft fields across import/reload, or warn and require discard confirmation when dirty.

---

## C. Already good patterns (use as templates)

| Area | Pattern | Key symbols |
|------|---------|-------------|
| Onboarding NDIS PDF | Pick → pending → upload on Next | `pickNdisPlanPdf`, `submitNdisStep` |
| Onboarding identity cards | Pending attachments → upload on `submitIdentity` | `pickIdentityCard`, `_persistIdentityCard` |
| Onboarding / client form / contractor photo | Local until submit/save | `onPhotoPicked` → pending; `_persistPhoto` / `_persistFormPhoto` |
| Requirement editors | Multi-file local hold → upload on requirement save | `pickFilesForRequirement`, `draft.localFiles`, `_uploadClientFiles` |
| Care-plan body / funding switches | Local until Save draft / Activate | `persistFacts` with `Future.wait` |
| Overview | Dirty drafts + explicit save | `saveOverviewProfile` |
| Contractor profile fields | Local drafts + `saveProfile` (photo excluded — A7) | |

**Best multi-file deferred reference:** `ClientsController.pickFilesForRequirement` + `_saveOneRequirement`.

---

## D. Suggested fix priority (for future work)

Ordered by user-visible pain × how often the surface is used during client setup:

| Pri | Item | Suggested outcome | Status |
|-----|------|-------------------|--------|
| P0 | A1 clinical (+ B1 busy scope, B3 toggle split) | Hold PDFs locally; upload on Save draft / Activate; row-level progress only | ✅ Done (2026-10-04) |
| P0 | A2 funding NDIS PDF | Align with onboarding deferral (`pick` pending → persist on Save) | ✅ Done (2026-10-04) |
| P1 | A3 / A4 legal pack & care consent | Row-level busy (keep mark-complete); don’t freeze sticky nav; check perms before pick (B4) | ✅ Done (2026-10-04) |
| P1 | A5 / A6 / B2 credentials | Non-blocking scan status; don’t lock whole create form | ✅ Done (2026-10-04) |
| P2 | A7 contractor photo | Match other profile fields (pending until Save) | ✅ Done (2026-10-04) |
| P2 | B5 / B6 onboarding Next & contacts | B5 KEEP resume-safe; B6 row-level `isSavingContact` (no sticky freeze) | ✅ Done (2026-10-04) |
| P3 | B7 serial cascades | Parallel uploads where safe | |
| P3 | B8 reload/import dirty handling | Don’t clobber unsaved care-plan body | |

**Separate workstream (web navigation):** **§F complete** — Path B (`go_router` on web only). See `docs/2026-09-27-go-router-web-only-plan.md` and `docs/adr-go-router-web-only.md`.

---

## E. Quick audit checklist (when changing a form)

When adding or editing a file field:

1. Does `onPick` call `uploadEvidence` / `_uploadClientFile` / `ClientLegalUploadHelper` immediately?
2. Does the step have **more than one** file slot?
3. Does upload set a **global** `isBusy` / `isSaving` that disables Save/Next/sibling fields?
4. Is permission checked **before** opening the picker?
5. Is there already a deferred pattern for the same document type elsewhere (e.g. onboarding NDIS vs care-plan NDIS)? Prefer one model.
6. After upload, is there a **second** Save required for related flags? If so, document or collapse the model.

---

## F. Web refresh / back / forward (platform UX)

**Status:** ✅ **Complete** (2026-09-27) — Path B shipped: `go_router` on Flutter Web; GetX named routes retained on mobile. Plan: [`docs/2026-09-27-go-router-web-only-plan.md`](./2026-09-27-go-router-web-only-plan.md) (Phases 0–6). ADR: [`docs/adr-go-router-web-only.md`](./adr-go-router-web-only.md).

**Why it hurt:** The app is primarily used in a browser. Refresh, Back, and Forward sometimes misbehaved, and a page refresh could throw staff out of mid-flow work (onboarding step, detail screen, support compose, etc.) into home, an empty detail, or a dead stack with no in-app back.

### F1. Problem

Workflow state often lives **in memory**, not in the **URL**. On web, refresh/back/forward only restore what the URL (and auth) can reconstruct.

| Failure mode | What happens |
|--------------|--------------|
| State only in `Get.arguments` / controller Rx | Visit/workforce detail, onboarding step, support compose, etc. — refresh recreates the app; memory is gone → empty or wrong screen |
| Session resume overrides the URL | `GatewayController` hydrates then `Get.offAllNamed(home)` — can yank the user off a deep link after refresh |
| Stack ≠ browser history | After refresh there is one route; in-app back vanishes; Chrome back/forward don’t match GetX’s stack |

**Resolution:** Web boots `GetMaterialApp.router` + `GoRouter` (`PathUrlStrategy`); feature nav via `AppNavigator` + shared `AppRoutes`; URL `?id=` / `?step=` / `?tab=` hydrate; gateway no longer steals deep links; `AppBackButton` / `backOrToParent` on pushed details; unknown routes → `UnknownRoutePage`. Mobile keeps GetX `GetPage` stack. Historical GetX-web notes: [`docs/web-refresh-back-button-fix.md`](./web-refresh-back-button-fix.md) (superseded for web).

**Key files (post-fix):** `lib/main.dart`, `lib/app/router/app_go_router.dart`, `lib/app/routes/app_navigator.dart`, `lib/app/routes/middlewares/auth_route_utils.dart`, `lib/app/controllers/gateway_controller.dart`, `lib/app/views/widgets/app_back_button.dart`.

### F2. Root solution

Every screen a user might refresh mid-workflow must be reconstructible from:

`path + query (+ auth tokens)`

`Get.arguments` stays an optional cache for speed, never the only way back into the screen.

### F3. Two ways to get there

| Path | Approach | Pros | Cons |
|------|----------|------|------|
| **A. Stay on GetX (URL-first discipline)** | Enforce `parameters` on every entity/wizard route; hydrate in `onInit` from URL; gate gateway redirect; roll out `AppBackButton` + `backOrToParent` | Faster short-term; no new router package; incremental | Easy to regress; checklist incomplete = same bugs forever |
| **B. Move navigation to `go_router`** | Declarative routes, path/query params, auth `redirect`, shell routes for staff tabs; keep GetX for DI/controllers if desired | Durable for web-primary; refresh/back/forward harder to break; shareable deep links | Higher migration cost; guards/bindings rewrite; risk during cutover |

**Product fit:** Web-primary → **B chosen and delivered** (web-only; GetX remains on mobile). Path A URL-first patterns (ids/steps in URL, hydrate-from-route, gateway gate, `AppBackButton`) were completed as Phase 0 and remain the shared contract both stacks use.

### F4. Highest leverage — done

1. ✅ **Stop cold-start home redirect** — gateway resume no longer replaces a valid deep URL with home.
2. ✅ **Id- and step-addressable routes** — details/wizards use URL `?id=` / `?step=` (etc.) and hydrate on load.
3. ✅ **Refresh-safe back** — `AppBackButton` + `backOrToParent` on pushed staff/contractor detail screens.

### F5. Priority (navigation workstream) — done

| Pri | Item | Outcome |
|-----|------|---------|
| P0 | F4.1 gateway redirect gate | ✅ Refresh on `/staff/...` stays after session hydrate |
| P0 | F4.2 client onboarding + remaining args-only details | ✅ `?id=` / `?step=` (etc.); reload from URL |
| P1 | F4.3 AppBackButton roll-out | ✅ Back after refresh + parent fallback |
| P2 | URL-first across visits / workforce / support / credentials | ✅ Via GoRoutes + `AppNavigator` (web) |
| P2–P3 | Path B `go_router` | ✅ Web-only cutover complete (Phases 0–6) |

---

## G. Source of this inventory

- Code inspection of `AppFileField` call sites, `FilePicker` / `ImagePicker` upload paths, care-plan stores, onboarding controller, credentials controller, requirement editors (2026-09-22).
- Starting point: `support_plan_clinical_section.dart` upload-on-pick UX.
- Web navigation: routing/auth inspection (`GetMaterialApp` / GetX, `GatewayController`, PathUrlStrategy, client-detail hydration docs) — 2026-09-22. **§F closed 2026-09-27** via web-only `go_router` (see plan + ADR linked in §F).
