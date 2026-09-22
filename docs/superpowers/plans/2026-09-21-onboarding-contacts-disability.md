# Onboarding Contacts Merge + Disability Card Number Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One **Contacts** wizard step (rep/nominee + soft emergency + add contacts) and optional **disability card number** with companion parity + Profile & docs edit.

**Architecture:** Collapse step indices 3+4 into one Contacts step; merge widgets; keep under-18 hard gate for representative and adult soft-skip. Add `disabilityCardNumberCtrl` mirrored from companion; persist via `value_json` on `disability_card` fact; surface in requirement drafts on Profile & docs.

**Tech Stack:** Flutter/GetX onboarding controller; existing contacts/rep submit methods; profile facts API.

**Spec:** Todo §5 Contacts merge (Q1–Q4) + Disability card (Q5–Q7).

**Depends on:** Prefer Plan 1 (nav) already shipped so finish path is safe while testing full wizards.

**Trust boundary:** PII (contacts, disability card number). Reuse existing `clientsManage` endpoints; no new routes. Numbers stored as existing fact `value_json` strings.

**Design principles:**
- **DRY:** Reuse `submitContacts` / `submitRepresentative` internals; one step UI calls both as needed.
- **SOLID:** Step widget presents; controller validates age gates and persists.
- **YAGNI:** No “People” label; no post-save-only contact gate.

---

## File Structure

| File | SRP |
|------|-----|
| `client_onboarding_controller.dart` | `stepLabels`, `maxStep`, step switch, disability number ctrl, persist/hydrate |
| Create: `onboarding_contacts_combined_step.dart` (or rewrite `onboarding_contacts_step.dart`) | Combined Contacts UI |
| Delete/stop using: `onboarding_representative_step.dart` as separate step | Logic folded in |
| `onboarding_identity_step.dart` | Wire disability number controller |
| `client_onboarding_view.dart` | Step switch cases |
| Requirement editors / profile drafts | Show disability card number |
| Tests: adult/child flow, identity other, contact form onboarding | Update indices |

**Current labels (today):**

```dart
static const stepLabels = [
  'Identity', 'Address', 'Preferences',
  'Contacts (Optional)', 'Representative', 'Support Plan', 'Legal',
];
static const maxStep = 6;
```

**Target after this plan (still 6 steps — Support Plan not yet split):**

```dart
static const stepLabels = [
  'Identity',
  'Address',
  'Preferences',
  'Contacts',
  'Support Plan',
  'Legal',
];
static const maxStep = 5;
```

(Wizard split plan expands Support Plan into four steps later.)

---

### Task 1: Disability card number — failing tests + wire

**Files:**
- Modify: `client_onboarding_controller.dart`
- Modify: `onboarding_identity_step.dart`
- Modify: tests covering identity card persist (extend `onboarding_identity_other_test.dart` or controller test)

- [ ] **Step 1: Failing test**

```dart
test('persist identity cards writes disability_card value_json', () async {
  when(() => mock.upsertProfileFact(any(), any(), any()))
      .thenAnswer((_) async => /* minimal fact */);
  // stub upload paths if pending attachment null

  c.disabilityCardNumberCtrl.text = 'DC-99';
  await c.submitIdentity(); // or private path via public submit

  final captured = verify(
    () => mock.upsertProfileFact('client-1', OnboardingKeys.disabilityCard, any()),
  ).captured;
  final upsert = captured.last as ProfileFactUpsert;
  expect(upsert.valueJson, 'DC-99');
});

test('hydrate restores disability card number from fact', () async {
  // seed profile facts with disability_card value_json 'DC-1'
  await c.resumeFromClient(_fakeClient);
  expect(c.disabilityCardNumberCtrl.text, 'DC-1');
});
```

Adapt to actual repository method names used by `_persistIdentityCard`.

- [ ] **Step 2: Run — FAIL** (no ctrl / valueJson null)

- [ ] **Step 3: Implement**

```dart
final disabilityCardNumberCtrl = TextEditingController();
```

Dispose/clear/reset alongside companion. Hydrate in fact switch:

```dart
case OnboardingKeys.disabilityCard:
  _hydrateCardAttachment(disabilityCardAttachment, fact);
  disabilityCardNumberCtrl.text = stored?.trim() ?? '';
  break;
```

Persist:

```dart
await _persistIdentityCard(
  clientId: clientId,
  requirementKey: OnboardingKeys.disabilityCard,
  category: OnboardingKeys.disabilityCard,
  attachment: disabilityCardAttachment,
  valueJson: _nullIfEmpty(disabilityCardNumberCtrl.text.trim()),
);
```

Identity UI:

```dart
OnboardingIdentityCardField(
  // ...
  numberController: controller.disabilityCardNumberCtrl,
  attachment: controller.disabilityCardAttachment,
  // same as companion
)
```

- [ ] **Step 4: Profile & docs** — ensure requirement draft for `disability_card` shows a text field for `valueJson` (same pattern as companion/pension). Grep `companion_card` in requirement editors and mirror.

- [ ] **Step 5: Tests PASS + commit**

```bash
cd frontend && flutter test test/features/clients/onboarding_identity_other_test.dart
git commit -am "feat: optional disability card number with profile parity"
```

---

### Task 2: Combined Contacts step — failing flow tests

**Files:**
- Modify: adult/child flow tests step indices
- Modify: `client_onboarding_controller.dart` step machine
- Create/modify contacts step widget

- [ ] **Step 1: Update failing expectations first**

In `client_onboarding_adult_flow_test.dart` / `child_flow_test.dart`:

- Adult: can advance past Contacts with zero contacts/nominee (soft skip).
- Child: cannot finish Contacts without representative.
- `stepLabels` length == 6; Contacts label == `'Contacts'`.
- No separate Representative step index.

Example:

```dart
test('adult soft-skips empty Contacts step', () async {
  c.step.value = 3; // Contacts
  expect(await c.next(), isTrue); // or submitCurrentStep
  expect(c.step.value, 4); // Support Plan
});

test('child blocks Contacts without representative', () async {
  // set DOB under 18
  c.step.value = 3;
  expect(await c.next(), isFalse);
  expect(c.errorMessage.value, isNotNull);
});
```

- [ ] **Step 2: Run — FAIL** on old indices

- [ ] **Step 3: Controller step machine**

```dart
static const maxStep = 5;
static const stepLabels = [
  'Identity',
  'Address',
  'Preferences',
  'Contacts',
  'Support Plan',
  'Legal',
];
```

Update `next`/switch:

```dart
3 => await submitContactsStep(), // new orchestrator
4 => await submitSupportPlan(),
5 => await finishOnboarding(),
```

```dart
Future<bool> submitContactsStep() async {
  final under18 = /* existing age helper */;
  if (under18) {
    final ok = await submitRepresentative(); // required
    if (!ok) return false;
  } else if (hasNomineeDraft) {
    final ok = await submitRepresentative();
    if (!ok) return false;
  }
  // Always allow contact list submit (may be empty for adults)
  return submitContacts(allowEmpty: !under18);
}
```

Reuse existing validation; expose `allowEmpty` if needed. Soft “Add emergency contact” stays a CTA in the widget, not a hard form.

Footer: remove separate “Skip nominee” only-on-rep-step; adults get step-level Skip / Next that calls soft skip.

- [ ] **Step 4: Widget**

Build `OnboardingContactsStep` (combined):

1. Section header: “Representative” if under18 else “Nominee (optional)”
2. Existing rep/nominee fields
3. Soft button: “Add emergency contact”
4. List of contacts + “Add another contact”
5. Adults: helper text “You can add contacts later”

Remove routing to `OnboardingRepresentativeStep` from `client_onboarding_view.dart`.

- [ ] **Step 5: Run flows + commit**

```bash
cd frontend && flutter test test/features/clients/client_onboarding_adult_flow_test.dart
cd frontend && flutter test test/features/clients/client_onboarding_child_flow_test.dart
cd frontend && flutter test test/features/clients/client_contact_form_onboarding_test.dart
git commit -am "feat: merge Contacts and Representative into one onboarding step"
```

---

## Design notes (App UI)

**IA (Contacts step):**
1. Rep/Nominee block (required vs optional by age)
2. Soft emergency CTA
3. Additional contacts list

**States:**

| | Loading | Empty | Error | Success |
|--|---------|-------|-------|---------|
| Contacts | Saving spinner on Next | Adult: empty OK + “add later” | Inline / banner for missing under-18 rep | Advance |
| Disability number | N/A | Optional blank | N/A | Persisted on identity submit |

**Copy:** Utility language — “Add emergency contact”, “Add another contact”, “You can add contacts later.” No happy talk.

---

## Test Plan & Verification

**Coverage target:** Adult skip, child block, disability persist+hydrate+profile edit each tested.

**Critical paths:**
- Adult finishes with empty contacts → flow test
- Child requires representative → flow test
- Disability number round-trip → controller test
- Profile & docs shows number → widget/controller test or manual

**Verification commands:**

```bash
cd frontend && flutter test test/features/clients/client_onboarding_adult_flow_test.dart
cd frontend && flutter test test/features/clients/client_onboarding_child_flow_test.dart
cd frontend && flutter test test/features/clients/onboarding_identity_other_test.dart
cd frontend && flutter test test/features/clients/client_onboarding_controller_test.dart
```

**Acceptance criteria:**
- [x] Single Contacts step labeled Contacts → Task 2
- [x] Under-18 rep required; adults soft-skip → Task 2
- [x] Disability number optional + Profile & docs → Task 1

**Shipped (2026-09-22).**


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
