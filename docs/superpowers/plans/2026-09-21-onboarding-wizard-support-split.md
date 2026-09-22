# Onboarding Wizard Support Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single Support Plan onboarding step with **NDIS**, **Care plan**, **Support Coordinator**, and **Support Specialists** steps; mirror coordinator vs specialists on the Care plan tab.

**Architecture:** Expand step machine to 9 steps after Contacts merge. Split `onboarding_support_plan_step.dart` into focused widgets; move allergies off Identity; drop `support_coordinator` from `SupportPlanSpecialistTypes.pickerTypes` while keeping hydrate of legacy SC-in-list; Care plan tab funding UI gets a dedicated SC subsection.

**Tech Stack:** Flutter/GetX; existing NDIS budget codec, specialists codec, clinical store patterns, profile facts.

**Spec:** Todo §5 wizard split (N1–N6, N1b defer extra budgets).

**Depends on:** Plan 3 (Contacts merge) — step indices assume Contacts is already one step.

**Trust boundary:** Health/PII (allergies, clinical PDFs, NDIS). Reuse authenticated profile-fact + document upload; no new public APIs. Soft-skip unless existing hard requirements.

**Design principles:**
- **DRY:** Reuse `NdisPlanBudgetsCodec`, `SupportPlanSpecialistsCodec`, funding/clinical stores where possible; extract shared field groups rather than duplicating Care plan tab widgets wholesale if coupling is high — prefer composing existing section widgets inside onboarding steps when safe.
- **SOLID:** One widget per step; codecs own JSON; tab and onboarding share specialist type list via `pickerTypes`.
- **YAGNI:** No extra budget lines (N1b). Plan manager stays on NDIS step only, separate from SC.

---

## File Structure

| File | SRP |
|------|-----|
| `client_onboarding_controller.dart` | 9-step labels, submit/skip per step, allergies move, SC dedicated fields |
| `client_onboarding_view.dart` | Step switch |
| Create: `onboarding_ndis_step.dart` | NDIS number/PDF/mgmt/manager/dates/budgets |
| Create: `onboarding_care_plan_step.dart` | Allergies + clinical + thin body + consent flags |
| Create: `onboarding_support_coordinator_step.dart` | Single SC form |
| Create: `onboarding_support_specialists_step.dart` | Dynamic specialists (no SC type) |
| Modify: `onboarding_identity_step.dart` | Remove allergies |
| Modify/retire: `onboarding_support_plan_step.dart` | Split or delete |
| `support_plan_specialist_types.dart` | `pickerTypes` without coordinator |
| `support_plan_funding_section.dart` + specialists panel | Tab parity |
| Tests: adult/child, specialist entry, funding consent, regression | Update step counts |

**Target `stepLabels`:**

```dart
static const maxStep = 8;
static const stepLabels = [
  'Identity',
  'Address',
  'Preferences',
  'Contacts',
  'NDIS',
  'Care plan',
  'Support Coordinator',
  'Support Specialists',
  'Legal',
];
```

---

### Task 1: pickerTypes exclude coordinator (TDD)

**Files:**
- Modify: `frontend/lib/features/clients/models/support_plan_specialist_types.dart`
- Modify: `frontend/test/features/clients/support_plan_specialist_entry_test.dart` (or section test)

- [ ] **Step 1: Failing test**

```dart
test('pickerTypes does not include support_coordinator', () {
  expect(
    SupportPlanSpecialistTypes.pickerTypes,
    isNot(contains(SupportPlanSpecialistTypes.supportCoordinator)),
  );
  expect(
    SupportPlanSpecialistTypes.pickerTypes,
    contains(SupportPlanSpecialistTypes.other),
  );
});

test('legacy support_coordinator remains valid for hydrate', () {
  expect(
    SupportPlanSpecialistTypes.isValid(
      SupportPlanSpecialistTypes.supportCoordinator,
    ),
    isTrue,
  );
});
```

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implementation**

```dart
static const pickerTypes = <String>[
  behaviouralTherapist,
  speechTherapist,
  occupationalTherapist,
  physiotherapist,
  other,
];
```

Keep `labels` and `isValid` including coordinator.

- [ ] **Step 4: PASS + commit**

```bash
cd frontend && flutter test test/features/clients/support_plan_specialist_entry_test.dart
git commit -am "fix: exclude support coordinator from specialist picker types"
```

---

### Task 2: Step machine + soft step widgets (skeleton with soft skip)

**Files:** controller, view, four new step widgets (can start as containers calling existing controller fields).

- [ ] **Step 1: Failing tests for labels/count**

```dart
test('onboarding has nine step labels in locked order', () {
  expect(ClientOnboardingController.stepLabels, [
    'Identity',
    'Address',
    'Preferences',
    'Contacts',
    'NDIS',
    'Care plan',
    'Support Coordinator',
    'Support Specialists',
    'Legal',
  ]);
  expect(ClientOnboardingController.maxStep, 8);
});
```

Update adult/child flows: after Contacts, next is NDIS; soft-skip NDIS/Care/SC/Specialists advances; Legal still finish.

- [ ] **Step 2: FAIL on old maxStep**

- [ ] **Step 3: Implement step switch**

```dart
Future<bool> submitCurrentStep() async {
  switch (step.value) {
    case 0: return submitIdentity();
    case 1: return submitAddress();
    case 2: return submitPreferences();
    case 3: return submitContactsStep();
    case 4: return submitNdisStep(soft: true);
    case 5: return submitCarePlanStep(soft: true);
    case 6: return submitSupportCoordinatorStep(soft: true);
    case 7: return submitSupportSpecialistsStep(soft: true);
    case 8: return finishOnboarding();
    default: return false;
  }
}
```

Soft skip: if step has no hard-required empty fields, persist whatever is present and `step++`. Mirror existing soft-gate patterns for legal.

Split persist logic currently in `submitSupportPlan` into the four methods. Move allergies upsert from identity submit into `submitCarePlanStep`.

- [ ] **Step 4: View cases**

```dart
4 => OnboardingNdisStep(controller: controller),
5 => OnboardingCarePlanStep(controller: controller),
6 => OnboardingSupportCoordinatorStep(controller: controller),
7 => OnboardingSupportSpecialistsStep(controller: controller),
8 => OnboardingLegalPackStep(controller: controller),
```

- [ ] **Step 5: Commit skeleton**

```bash
git commit -am "feat: split onboarding support plan into four soft-skippable steps"
```

---

### Task 3: NDIS step fields

**Files:** `onboarding_ndis_step.dart`, controller NDIS fields (many already exist on support plan step).

- [ ] **Step 1: Test** — submitNdisStep persists number, plan type, dates, budgets JSON via existing keys (reuse funding consent tests as templates).

- [ ] **Step 2: UI** — NDIS number, PDF (`AppFileField` if Plan 2 landed), plan management type, conditional plan manager block, start/end `AppDateField`, budgets Core/CB/Capital/Other (+ other label). **Do not** add SC/plan-manager/employment budget lines.

- [ ] **Step 3: Commit**

```bash
git commit -am "feat: onboarding NDIS step with category budgets"
```

---

### Task 4: Care plan step (allergies + clinical + body + consent flags)

**Files:** `onboarding_care_plan_step.dart`, identity (remove allergies), clinical upload helpers.

- [ ] **Step 1: Test** — allergies no longer required/persisted on identity; care plan step upserts allergies fact.

- [ ] **Step 2: Move allergies field** from identity widget to care plan step.

- [ ] **Step 3: Compose clinical flags/uploads + thin care body + consent flags (info share / specific supports). Legal pack PDFs stay on Legal.

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: onboarding Care plan step; allergies leave Identity"
```

---

### Task 5: Support Coordinator + Specialists steps

**Files:** coordinator/specialists step widgets; controller SC fields vs `supportSpecialists` list.

- [ ] **Step 1: Tests**

```dart
test('coordinator step persists single SC specialist entry', () async { ... });

test('specialists step picker has no coordinator type', () async {
  // pump specialists step; open add sheet; expect no 'Support coordinator'
});
```

- [ ] **Step 2: Coordinator step** — single form bound to SC fact fields / one `SupportPlanSpecialistEntry` of type coordinator (not in add-picker). Soft skip if empty.

- [ ] **Step 3: Specialists step** — reuse `SupportPlanSpecialistsPanel` (picker already updated). Persist `support_plan_specialists` JSON **without** dropping legacy hydrated SC if present elsewhere — coordinator step owns SC write; specialists codec encode should not duplicate SC if coordinator step writes separately. Document merge rule in controller:

```dart
// When persisting specialists JSON: filter out support_coordinator entries
// if coordinator step writes SC via dedicated facts OR keep one SC from coordinator form only.
```

**Eng-review lock (persist merge):**
1. Coordinator step owns the single `support_coordinator` entry (create/update/clear).
2. Specialists step list **never** contains coordinator rows in the UI.
3. On persist: build JSON array = `[scEntry?] + nonScEntries` (at most one SC).
4. On hydrate: partition by type — SC → coordinator form; rest → specialists list.
5. Legacy multi-SC in JSON: keep first SC in coordinator form; drop extras from UI (log/debug only; YAGNI no merge UI).

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: dedicated Support Coordinator and Specialists onboarding steps"
```

---

### Task 6: Care plan tab parity

**Files:** `support_plan_funding_section.dart`, `support_plan_specialists_panel.dart`, funding-consent store.

- [ ] **Step 1: Failing tab test** — add specialist sheet excludes coordinator; funding section shows SC subsection.

- [ ] **Step 2: UI** — SC fields in funding/care plan tab; specialists panel uses `pickerTypes`.

- [ ] **Step 3: Run**

```bash
cd frontend && flutter test test/features/clients/support_plan_funding_consent_test.dart
cd frontend && flutter test test/features/clients/support_plan_specialist_section_test.dart
cd frontend && flutter test test/features/clients/client_detail_care_plan_tab_test.dart
```

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: Care plan tab splits coordinator from specialists"
```

---

### Task 7: Resume hydrate + regression suite

- [ ] Update resume paths for new step indices / incomplete metadata.
- [ ] Run full client onboarding test folder:

```bash
cd frontend && flutter test test/features/clients/client_onboarding_adult_flow_test.dart \
  test/features/clients/client_onboarding_child_flow_test.dart \
  test/features/clients/client_onboarding_regression_test.dart \
  test/features/clients/client_onboarding_controller_test.dart \
  test/features/clients/client_onboarding_view_smoke_test.dart
```

- [ ] Commit test fixes.

---

## Design notes (App UI)

**Wizard progress:** Stepper/header shows 9 labels; current step name prominent. Soft-skip secondary to Next (same pattern as today’s optional steps).

**IA per step:** One job each — NDIS money/plan; Care clinical/consent flags; one SC; many specialists.

**States table:**

| Step | Loading | Empty | Error | Soft skip |
|------|---------|-------|-------|-----------|
| NDIS | saving | blank OK | field errors | Yes |
| Care plan | saving | blank OK | upload errors | Yes |
| Coordinator | saving | blank OK | validation | Yes |
| Specialists | saving | empty list OK | validation | Yes |

**Journey:** Staff can finish day-one onboarding without full NDIS paperwork; incomplete soft-gate only where already required (legal consent patterns).

---

## Test Plan & Verification

**Coverage target:** Step label contract test; pickerTypes guard; adult soft-skip through four new steps; child still blocked on Contacts rep; Care plan tab picker regression; allergies not on identity persist.

**Critical paths:**
- Full adult soft-skip finish → regression/adult flow
- NDIS budgets round-trip → funding tests + ndis step test
- SC on coordinator step not in specialists add sheet → widget test
- Care plan tab parity → section tests

**Edge cases:**
- Legacy JSON with SC in list hydrates into coordinator form
- Plan-managed shows plan manager; SC still separate
- Extra budget lines absent (assert keys not present)

**Verification commands:**

```bash
cd frontend && flutter test test/features/clients/client_onboarding_adult_flow_test.dart
cd frontend && flutter test test/features/clients/client_onboarding_child_flow_test.dart
cd frontend && flutter test test/features/clients/support_plan_specialist_entry_test.dart
cd frontend && flutter test test/features/clients/support_plan_funding_consent_test.dart
cd frontend && flutter test test/features/clients/client_detail_care_plan_tab_test.dart
```

**Acceptance criteria:**
- [x] 9-step order locked → Task 2
- [x] NDIS/Care/SC/Specialists soft-skippable → Tasks 2–5
- [x] Allergies on Care plan only → Task 4
- [x] Tab picker excludes SC; SC subsection exists → Task 6
- [x] No extra budget lines → Task 3 / YAGNI

**Shipped (2026-09-22).** Deferred: N1b extra budget lines (SC / plan-manager / employment).


## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | SKIPPED | Scope locked in todo 2026-09-21; five vertical slices |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | SKIPPED | Not run |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR | Hydration-by-id primary; no inline ClientsController put; SC JSON merge locked; legal ids via microsecond seq; Task 0 category probe before schema |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR | App UI classifier; IA/states/journey baked into each UI plan; designer mockups blocked (no OpenAI key) — live `/design-review` after ship |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | SKIPPED | Not run |

**VERDICT:** ENG + DESIGN CLEARED — ready to implement (start with nav hydration plan).

NO UNRESOLVED DECISIONS
