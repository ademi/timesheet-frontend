# App File Field + Profile Photo Chrome Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** File uploads and profile photo pickers use the same filled + outlined field chrome as `AppDateField` / `AppSwitchField` / text fields.

**Architecture:** Add `AppFileField` wrapping label + status text + pick/clear actions inside an `InputDecorator` driven by `InputDecorationTheme`. Restyle `ProfilePhotoEditor` shell the same way (keep picker/upload behaviour). Migrate onboarding identity cards, NDIS PDF, legal uploads, then other high-traffic upload call sites.

**Tech Stack:** Flutter Material `InputDecorator` / `InputDecoration`; existing `FilePicker` / `ImagePicker`.

**Spec:** `docs/client-detail-navigation-todo.md` §5 “File uploads + profile photos”.

**Prerequisite:** `AppDateField` / `AppSwitchField` already exist under `frontend/lib/shared/widgets/`. Commit any uncommitted chrome WIP before starting this plan.

**Trust boundary:** Visual shell only. Keep existing MIME filters (PDF/images). No new upload endpoints.

**Design principles:**
- **DRY:** One `AppFileField`; callers pass label + filename + callbacks.
- **SOLID:** Widget owns chrome; parent owns pick/upload/complete state.
- **YAGNI:** Do not build a full document-management UI — field chrome only.

---

## File Structure

| File | SRP / seam |
|------|------------|
| Create: `frontend/lib/shared/widgets/app_file_field.dart` | Filled outlined file-picker field |
| Modify: `frontend/lib/shared/widgets/profile_photo_editor.dart` | Field-like bordered container around avatar + actions |
| Create: `frontend/test/shared/widgets/app_file_field_test.dart` | Chrome + callbacks |
| Modify: onboarding identity / legal / NDIS upload UIs | Use `AppFileField` |
| Modify: clinical / requirement / credential pickers (as found by grep) | Same chrome |

---

### Task 1: AppFileField widget (TDD)

**Files:**
- Create: `frontend/lib/shared/widgets/app_file_field.dart`
- Create: `frontend/test/shared/widgets/app_file_field_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/widgets/app_file_field.dart';

void main() {
  testWidgets('shows label and empty hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFileField(
            label: 'NDIS plan PDF',
            fileName: null,
            onPick: () {},
          ),
        ),
      ),
    );
    expect(find.text('NDIS plan PDF'), findsOneWidget);
    expect(find.text('No file'), findsOneWidget);
  });

  testWidgets('shows file name and clear when present', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFileField(
            label: 'Consent',
            fileName: 'consent.pdf',
            onPick: () {},
            onClear: () => cleared = true,
          ),
        ),
      ),
    );
    expect(find.text('consent.pdf'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear'));
    expect(cleared, isTrue);
  });

  testWidgets('invokes onPick when Choose tapped', (tester) async {
    var picked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFileField(
            label: 'Upload',
            fileName: null,
            onPick: () => picked = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose file'));
    expect(picked, isTrue);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd frontend && flutter test test/shared/widgets/app_file_field_test.dart
```

- [ ] **Step 3: Implement**

Mirror `AppDateField` styling:

```dart
import 'package:flutter/material.dart';

/// File picker control styled like a filled outlined [TextField].
class AppFileField extends StatelessWidget {
  const AppFileField({
    super.key,
    required this.label,
    required this.fileName,
    required this.onPick,
    this.onClear,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.pickLabel = 'Choose file',
    this.emptyHint = 'No file',
  });

  final String label;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final String pickLabel;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = fileName != null && fileName!.trim().isNotEmpty;
    final display = hasFile ? fileName!.trim() : emptyHint;
    final hintStyle = theme.inputDecorationTheme.hintStyle ??
        theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        errorText: errorText,
        enabled: enabled,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasFile && onClear != null && enabled)
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            TextButton(
              onPressed: enabled ? onPick : null,
              child: Text(pickLabel),
            ),
          ],
        ),
      ),
      child: Text(
        display,
        style: hasFile ? theme.textTheme.bodyLarge : hintStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
```

Tune `suffixIcon` if `InputDecorator` layout fights the Row — acceptable alternative is a trailing `Row` below the decorator **inside** a bordered `InkWell` matching `AppDateField`’s `InputDecorator` approach exactly (read `app_date_field.dart` and copy structure).

- [ ] **Step 4: Run — expect PASS**

```bash
cd frontend && flutter test test/shared/widgets/app_file_field_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/shared/widgets/app_file_field.dart \
  frontend/test/shared/widgets/app_file_field_test.dart
git commit -m "feat: add AppFileField matching text field chrome"
```

---

### Task 2: ProfilePhotoEditor field chrome

**Files:**
- Modify: `frontend/lib/shared/widgets/profile_photo_editor.dart`
- Create/modify: `frontend/test/shared/widgets/profile_photo_editor_test.dart` (if none exists, add smoke)

- [ ] **Step 1: Failing golden/smoke test**

```dart
testWidgets('ProfilePhotoEditor wraps content in InputDecorator label', (
  tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: ProfilePhotoEditor(label: 'Profile photo', showLabel: true),
      ),
    ),
  );
  expect(find.text('Profile photo'), findsOneWidget);
  expect(find.byType(InputDecorator), findsOneWidget);
});
```

- [ ] **Step 2: Run — FAIL if no InputDecorator**

- [ ] **Step 3: Implement shell**

Wrap existing avatar + action buttons in:

```dart
InputDecorator(
  decoration: InputDecoration(
    labelText: widget.showLabel ? widget.label : null,
    enabled: widget.enabled && !widget.readOnly,
  ),
  child: Row(
    children: [
      // existing CircleAvatar / image stack at widget.size
      // existing change/remove IconButtons
    ],
  ),
)
```

Keep `size`, `readOnly`, network/proxy behaviour unchanged.

- [ ] **Step 4: Run existing photo-related tests**

```bash
cd frontend && flutter test test/shared/widgets/profile_photo_editor_test.dart 2>/dev/null || true
cd frontend && flutter test test/features/clients/client_onboarding_view_smoke_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/shared/widgets/profile_photo_editor.dart \
  frontend/test/shared/widgets/profile_photo_editor_test.dart
git commit -m "style: ProfilePhotoEditor uses filled field chrome"
```

---

### Task 3: Migrate onboarding upload call sites

**Files (expected; grep to confirm):**
- `frontend/lib/features/clients/widgets/onboarding/onboarding_identity_step.dart` (and identity card field widget if separate)
- `frontend/lib/features/clients/widgets/onboarding/onboarding_legal_pack_step.dart`
- Support-plan / NDIS PDF UI inside onboarding support step
- Any `OnboardingIdentityCardField` / upload `OutlinedButton`

- [ ] **Step 1: Grep call sites**

```bash
cd frontend && grep -rn "OutlinedButton\|FilePicker\|Upload PDF\|pickFiles" \
  lib/features/clients/widgets/onboarding lib/features/clients/widgets/steps \
  lib/features/clients/widgets/support_plan_clinical_section.dart \
  lib/features/clients/widgets/client_requirement_editors.dart | head -80
```

- [ ] **Step 2: Replace button rows with AppFileField**

Example for a legal item:

```dart
Obx(() => AppFileField(
  label: 'Consent PDF',
  fileName: controller.consentFileName.value, // or derive from complete flag
  onPick: controller.uploadConsent,
  onClear: controller.canClearConsent ? controller.clearConsent : null,
  helperText: controller.consentComplete.value ? 'Marked complete' : null,
))
```

Wire to existing controller methods — do not change upload API.

- [ ] **Step 3: Widget smoke**

```bash
cd frontend && flutter test test/features/clients/client_onboarding_view_smoke_test.dart
cd frontend && flutter test test/features/clients/client_legal_upload_helper_test.dart
```

- [ ] **Step 4: Commit**

```bash
git commit -am "style: onboarding uploads use AppFileField"
```

---

### Task 4: Migrate remaining high-traffic upload UIs

**Files:** clinical section, requirement editors, credential evidence (from grep).

- [ ] **Step 1: Migrate each site to AppFileField** (same pattern as Task 3).
- [ ] **Step 2: Run focused tests for touched features.**
- [ ] **Step 3: Commit**

```bash
git commit -am "style: migrate upload controls to AppFileField"
```

---

## Design notes (App UI)

**Hierarchy per field:** Label (primary) → file name / “No file” → Choose/Clear actions.  
**Empty:** “No file” in hint style — not a dead button.  
**Error:** `errorText` on decorator (validation messages stay at field).  
**Touch:** Choose/Clear ≥ 48dp via IconButton/TextButton theme.  
**AI slop avoid:** No icon-in-colored-circle upload cards; no dashed dropzone novelty — match existing InputDecoration.

---

## Test Plan & Verification

**Coverage target:** 100% of `AppFileField` public behaviours (empty, named, pick, clear, disabled); smoke onboarding still builds.

**Critical paths:**
- Identity card PDF pick still uploads → manual + existing identity tests
- Legal consent upload → `client_legal_upload_helper_test` + manual
- Profile photo change/remove → manual on detail + onboarding

**Edge cases:**
- Long file names ellipsize → widget test
- `enabled: false` → Choose does nothing
- `onClear` null → no clear button

**Verification commands:**

```bash
cd frontend && flutter test test/shared/widgets/app_file_field_test.dart
cd frontend && flutter test test/features/clients/client_onboarding_view_smoke_test.dart
cd frontend && flutter analyze lib/shared/widgets/app_file_field.dart lib/shared/widgets/profile_photo_editor.dart
```

**Acceptance criteria:**
- [x] Uploads look like text fields (fill + border) → Tasks 1–3
- [x] Profile photo uses same shell → Task 2
- [x] Behaviour unchanged (pick/upload/complete) → regression tests

**Shipped (2026-09-22).** Deferred: none for this slice (photo field full-width justify polish landed as a follow-up tweak).


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
