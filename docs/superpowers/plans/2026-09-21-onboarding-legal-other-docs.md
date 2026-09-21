# Onboarding Legal Other Documents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the Legal step, staff can add optional extra legal documents (preset type or Other + free-text name) with the same card + PDF complete pattern as Consent / Service Agreement / Acknowledgement; surface them on Profile & docs after onboarding.

**Architecture:** Extend legal pack step with a dynamic list of “other” docs. Persist via existing client document upload pipeline + a profile fact or metadata list holding `{type, label, documentId, complete}` entries. Reuse `ClientLegalUploadHelper` patterns (or a thin sibling) without inventing signer fields for other docs.

**Tech Stack:** Flutter/GetX; documents API already used by legal uploads; Profile & docs requirement/document list.

**Spec:** Todo §5 Legal pack L1–L5.

**Depends on:** Prefer Plan 2 (`AppFileField`) for upload chrome; can ship with temporary OutlinedButton then restyle.

**Trust boundary:** Document upload of PDFs under authenticated client document endpoints. Validate PDF-only at picker (same as existing legal). Category string allowlist / sanitize Other label (trim, max length 120). No new unauthenticated routes.

**Design principles:**
- **DRY:** Reuse legal upload helper + complete flags pattern.
- **SOLID:** Step owns list UI; helper owns upload; Profile & docs owns post-onboarding display.
- **YAGNI:** No signer name for other docs; optional only; Profile & docs only (not Care plan consent).

---

## File Structure

| File | SRP |
|------|-----|
| Create: `frontend/lib/features/clients/models/legal_other_document.dart` | Draft model for other doc rows |
| Modify: `client_onboarding_controller.dart` | List observable, add/remove, upload, persist/hydrate |
| Modify: `onboarding_legal_pack_step.dart` | UI for list + Add a document |
| Modify: `client_legal_upload_helper.dart` or sibling | Upload with category `legal_other` (or agreed category) |
| Modify: Profile & docs widgets / requirement drafts | List other legal docs |
| Backend (only if category enum rejects unknown): migration or allowlist update | Confirm before coding — probe existing document category validation |
| Tests: controller + legal step + helper | |

---

### Task 0: Probe document category constraints (evidence before schema)

- [x] **Step 1: Find allowed document categories**

**Evidence (2026-09-21):**

- `docs.documents.category` is nullable `text` with **no** category CHECK — only `owner_type` and `scan_status` are constrained (`V004__clients_and_docs.sql`).
- Client upload path (`documents/service.py` `_validate_upload_request`) applies `CONTRACTOR_DOCUMENT_CATEGORIES` **only** when `owner_type == "contractor"`. Client uploads accept any category string (or null).
- Onboarding legal PDF categories in use today: `consent` (legal acceptance + upload), `service_agreement`, `acknowledgement` (`client_legal_upload_helper.dart`; requirement rows in `V033__client_onboarding_v1.sql` with matching `document_category` for SA/ack profile-fact links).
- Profile fact document links validate category against the requirement’s `document_category` when `document_id` is set (`profile_service._assert_document_for_client`), not at raw upload time.
- Requirement catalog `document_category` is free text on `clients.client_type_requirements` (no enum).

- [x] **Step 2: Decide persistence**

| Option | When to use |
|--------|-------------|
| A) Documents with category `legal_other` + fact `legal_other_documents` JSON list | Preferred if categories are open/stringly |
| B) Reuse generic category + fact metadata only | If DB check constraint is closed |

**Decision: Option A.**

- **Upload:** Reuse existing `ClientLegalUploadHelper` / `DocumentPipeline` client upload with **`category: legal_other`** (same stack as consent / SA / ack).
- **Persist:** Upsert profile fact **`legal_other_documents`** with `value_json` = list of `{type, label, document_id}` (no per-row requirement keys; mirrors `support_plan_specialists` JSON fact pattern from `V044`).
- **Do not** add a second upload stack.

**Migration (later task, not Task 0):** No migration to expand document category allowlist. **Do** add a minimal seed migration (e.g. `V0XX__legal_other_documents_fact.sql`) inserting `legal_other_documents` on patient type: `kind=field`, `capture_modes=['field']`, `value_type=json`, `document_category=NULL`, optional `field_schema_json` e.g. `{"schema":"legal_other_documents_v1"}`, plus API test for JSON upsert — same shape as `V044` / `test_client_onboarding_v044.py`.

---

### Task 1: Model + controller list (TDD)

**Files:**
- Create: `legal_other_document.dart`
- Modify: controller
- Create: `frontend/test/features/clients/legal_other_document_test.dart`

- [ ] **Step 1: Failing tests**

```dart
test('Other type requires non-empty custom label to be complete-ready', () {
  final row = LegalOtherDocumentDraft(
    id: '1',
    typeKey: 'other',
    customLabel: '  ',
  );
  expect(row.displayLabel, isNull);
  expect(row.canUpload, isFalse);
});

test('preset type uses catalog label', () {
  final row = LegalOtherDocumentDraft(
    id: '1',
    typeKey: 'guardianship_order',
    customLabel: null,
  );
  expect(row.displayLabel, 'Guardianship order'); // use real preset from catalog
});
```

Define presets explicitly (locked at implement time — examples):

```dart
const legalOtherTypePresets = <String, String>{
  'guardianship_order': 'Guardianship order',
  'court_order': 'Court order',
  'power_of_attorney': 'Power of attorney',
  'other': 'Other',
};
```

(Adjust labels to product language if a prior list exists in codebase — grep first.)

- [ ] **Step 2: Implement model**

```dart
class LegalOtherDocumentDraft {
  LegalOtherDocumentDraft({
    required this.id,
    required this.typeKey,
    this.customLabel,
    this.documentId,
    this.fileName,
    this.complete = false,
  });

  final String id;
  String typeKey;
  String? customLabel;
  String? documentId;
  String? fileName;
  bool complete;

  String? get displayLabel {
    if (typeKey == 'other') {
      final t = customLabel?.trim() ?? '';
      return t.isEmpty ? null : t;
    }
    return legalOtherTypePresets[typeKey];
  }

  bool get canUpload => displayLabel != null;
}
```

Controller:

```dart
final legalOtherDocs = <LegalOtherDocumentDraft>[].obs;

void addLegalOtherDoc() {
  // Same id scheme as SupportPlanSpecialistEntry._nextId — no uuid package.
  legalOtherDocs.add(LegalOtherDocumentDraft(
    id: 'legal-other-${DateTime.now().microsecondsSinceEpoch}-${legalOtherDocs.length}',
    typeKey: 'other',
  ));
}

void removeLegalOtherDoc(String id) {
  legalOtherDocs.removeWhere((e) => e.id == id);
}
```

- [ ] **Step 3: PASS + commit**

```bash
cd frontend && flutter test test/features/clients/legal_other_document_test.dart
git commit -am "feat: legal other document draft model"
```

---

### Task 2: Upload + persist/hydrate

**Files:** controller, helper, backend if needed.

- [ ] **Step 1: Failing controller test**

```dart
test('uploadLegalOther marks row complete and stores document id', () async {
  when(() => mock.uploadClientDocument(/*...*/))
      .thenAnswer((_) async => 'doc-1');
  c.addLegalOtherDoc();
  c.legalOtherDocs.first.typeKey = 'court_order';
  await c.uploadLegalOther(c.legalOtherDocs.first.id, fakeBytes, 'order.pdf');
  expect(c.legalOtherDocs.first.complete, isTrue);
  expect(c.legalOtherDocs.first.documentId, 'doc-1');
});

test('finishOnboarding succeeds with zero other legal docs', () async {
  // existing finish stubs...
  expect(await c.finishOnboarding(), isTrue);
});
```

- [ ] **Step 2: Implement upload** via helper with category from Task 0; PDF-only FilePicker.

- [ ] **Step 3: Persist fact** on legal submit / finish:

```dart
await _upsertFact(
  clientId,
  'legal_other_documents',
  legalOtherDocs
      .where((e) => e.complete && e.documentId != null)
      .map((e) => {
            'type': e.typeKey,
            'label': e.displayLabel,
            'document_id': e.documentId,
          })
      .toList(),
);
```

Hydrate on resume into `legalOtherDocs`.

- [ ] **Step 4: Security tests**

```dart
test('Other label longer than 120 chars is rejected', () async { ... });
test('upload rejected when displayLabel null', () async { ... });
```

- [ ] **Step 5: Commit**

```bash
git commit -am "feat: persist optional legal other documents"
```

---

### Task 3: Legal step UI

**Files:** `onboarding_legal_pack_step.dart`

- [ ] **Step 1: Widget test** — finds “Add a document”; Other shows text field; incomplete row removable.

- [ ] **Step 2: UI structure**

1. Existing Consent / SA / Acknowledgement cards unchanged (including Consent signer).
2. For each `legalOtherDocs` row: type dropdown, conditional Other text field, `AppFileField` (or existing upload chrome), complete state, remove if incomplete.
3. Button: “Add a document”.

- [ ] **Step 3: Commit**

```bash
git commit -am "feat: Legal step Add a document for other PDFs"
```

---

### Task 4: Profile & docs surface

**Files:** profile section / requirement list widgets.

- [ ] **Step 1: Test** — profile bundle with `legal_other_documents` fact renders labels + open/download affordance (match existing doc row pattern).

- [ ] **Step 2: Implement read-only or edit-upload parity with other profile docs — **Profile & docs only** (not Care plan consent section).

- [ ] **Step 3: Commit**

```bash
git commit -am "feat: show legal other documents on Profile and docs"
```

---

## Design notes (App UI)

**IA:** Fixed three legal cards first; optional others below; primary action “Add a document”.  
**Empty:** No other docs — no placeholder card wall; just the add button.  
**Other type:** Label field visible only when type == Other; required before upload.  
**Copy:** “Add a document”, “Document type”, “Name” (for Other) — no signer field.

---

## Test Plan & Verification

**Coverage target:** Model validation, upload complete path, finish with zero others, Other-label required, profile render; backend category test if migration added.

**Critical paths:**
- Add Other + PDF → complete → finish → Profile & docs shows row
- Soft finish with no others → still OK

**Edge cases:**
- Remove incomplete draft row
- Preset type without custom label
- Oversized Other label rejected
- Non-PDF rejected by picker filters

**Abuse / negative (trust boundary):**
- Unauthenticated upload impossible via existing guards (no change) — covered by existing API auth tests if backend touched
- Category not in allowlist rejected — backend test if allowlist expanded

**Verification commands:**

```bash
cd frontend && flutter test test/features/clients/legal_other_document_test.dart
cd frontend && flutter test test/features/clients/client_legal_upload_helper_test.dart
cd frontend && flutter test test/features/clients/client_onboarding_controller_test.dart --name "finishOnboarding"
# if backend migration:
cd backend/timesheet-backend && .venv/bin/pytest tests/ -k legal_other -q
```

**Acceptance criteria:**
- [ ] Optional other docs with type dropdown + Other free text → Tasks 1–3
- [ ] Same card/PDF complete pattern; no signer → Task 3
- [ ] Profile & docs only after onboarding → Task 4
- [ ] Zero others allowed → Task 2


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
