# Workforce Contractor Card Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Before product code:** this file is the plan. Finish `/gstack-plan-eng-review` before feature commits.

**Goal:** Give the staff contractor card the same tabbed shape as the client card, with full-width actions, required-document editing on credential review, plus Visits and Schedule tabs — and center the roster board on a wider max width.

**Architecture:** Frontend-first vertical slices. Extract two small shared layout widgets (`SubjectTabBar`, `PageContentWidth.wide`) so client and contractor cards share tab chrome and roster can grow the cap without a one-off `ConstrainedBox`. Reuse `GET /v1/visits` (add staff `contractor_id` query) and add one read-only `GET /v1/engagements/{id}/availability` that wraps existing `contractor_schedule.service.list_availability`. No new timetable endpoint — group the same visit list by day.

**Tech Stack:** Flutter/GetX (`frontend/`), FastAPI/asyncpg (`backend/timesheet-backend/`), existing `PageContent` / `EqualFillRow` / `ClientDetailVisitsSection` / `partitionClientVisits` / roster overlay availability rows.

---

## Scope (what this plan covers)

From [TODOS.yaml](../../../../TODOS.yaml) **V2** only:

- Contractor card: tab view like the client card
- Credentials tab; move Required Documents to the **top** of Review Credentials, with clearer edit copy
- Full-width actions: lifecycle, Load credentials, View / Download
- Current + upcoming visits on a contractor-card tab (client name/job on each row)
- Timetable + availability on a contractor-card tab (read-only)
- Roster: cap content width, center it (wider preset than workflow 960 if needed)

**NOT in this plan**

- Staff **edit** of contractor availability/leave (contractor self-serve stays on Schedule)
- New timetable API (`/contractor-me/timetable` stays contractor-JWT-only)
- Putting `client_name` on `VisitOut` (job title already identifies the support)
- Roster stale-board / pin dates / horizon TZ (`TODOS.md`)
- Rewriting `WorkforceController` into multiple GetX controllers

---

## File structure

New units (SRP + seam):

| Unit | Path | Responsibility | Seam |
|------|------|----------------|------|
| `SubjectTabBar` | `frontend/lib/shared/widgets/subject_tab_bar.dart` | Horizontal ChoiceChip tabs | `labels`, `index`, `onChanged`, `keyPrefix` |
| `RequiredDocCategoriesEditor` | `frontend/lib/features/engagements/widgets/required_doc_categories_editor.dart` | Chip picker + save for engagement required docs | `choices`, `selected`, `canEdit`, `onToggle`, `onSave` |
| `AvailabilityRulesReadout` | `frontend/lib/shared/widgets/availability_rules_readout.dart` | Read-only Mon–Sun windows | `List<AvailabilityRuleOut>` (roster overlay DTO) |
| `VisitDayAgenda` | `frontend/lib/shared/widgets/visit_day_agenda.dart` | Group visits by local day | `List<AgendaVisit>` |
| `list_engagement_availability` | `backend/timesheet-backend/app/modules/engagements/service.py` | Tenant-scoped availability for one engagement | `GET /v1/engagements/{id}/availability` |

Reuse (DRY — do not rebuild):

- Client card chrome: [client_detail_view.dart](../../../lib/features/clients/views/client_detail_view.dart) photo + `SubjectTabBar` + `PageContent`
- Visits list UI: [client_detail_visits_section.dart](../../../lib/features/clients/widgets/client_detail_visits_section.dart) with `showPast: false` (YAML asks current + upcoming only)
- Split upcoming/current: move [client_visit_windows.dart](../../../lib/features/clients/utils/client_visit_windows.dart) to `frontend/lib/features/visits/utils/visit_windows.dart`; keep `partitionClientVisits` as a re-export from the clients path so existing tests do not churn
- Visit fetch: `VisitsRepository.listVisits` after adding `contractorId`
- Availability rows: `contractor_schedule.service.list_availability` (do not copy SQL)
- Full-width pairs: existing `EqualFillRow`
- Roster overlay DTO `AvailabilityRuleOut` for the readout (same `day_of_week` / times as overlay)

**SOLID:** tab chrome does not know workforce; required-doc editor does not know review decisions; availability GET does not write; visit list filter stays in `list_visits`. **YAGNI:** no staff PUT availability; no leave tab; no `WorkforceDetailController`.

Duplication accepted: contractor Schedule **Timetable** and **Visits** both show visits (list vs day agenda). Different jobs for staff; do not merge the tabs. Timetable includes past visits in the fetch window; Visits tab does not.

```
WorkforceDetailView
  header (photo + name)     — always visible
  SubjectTabBar
  PageContent
    Overview  → status, lifecycle (stretch), rates
    Credentials → Review CTA only (ended: hide)
    Visits → ClientDetailVisitsSection(showPast: false)
    Schedule → AvailabilityRulesReadout + VisitDayAgenda
         \ GET /engagements/{id}/availability
         \ GET /visits?contractor_id=

StaffCredentialReviewView
  RequiredDocCategoriesEditor   ← moved from contractor card
  Load credentials (stretch)
  credential cards
    EvidenceDocumentActions → EqualFillRow View|Download
```

---

## Design principles (where they apply)

- **DRY:** One `SubjectTabBar` for client + contractor. One `RequiredDocCategoriesEditor` (review only). `partitionClientVisits` reused. Availability SQL stays in `list_availability`.
- **SOLID:** New widgets have one reason to change. `GET availability` is read-only. `contractor_id` on visits is one query param in the existing list function.
- **YAGNI:** No staff availability editor. No new timetable route. No `client_name` on `VisitOut`. Roster uses `Breakpoints.maxContent` (1200), not a fourth magic number.

---

## Security (trust boundary)

This slice **does** cross a trust boundary: staff `contractor_id` on `GET /v1/visits`, and a new staff availability GET (contractor weekly windows are scheduling PII).

STRIDE / OWASP folded in:

| Threat | Control | Test |
|--------|---------|------|
| IDOR other tenant’s visits via `contractor_id` | `list_visits` always `WHERE v.tenant_id = $1`; unknown UUID → `[]` | `test_list_visits_foreign_contractor_id_returns_empty` |
| Contractor spoofs another worker’s `contractor_id` | Apply query `contractor_id` **only** when `actor_type == tenant_member`. Contractors keep JWT-resolved id (existing ignore of query `contractor_id` on `/contractor-me/timetable`) | `test_list_visits_contractor_actor_ignores_query_contractor_id` |
| IDOR availability | `_get_engagement_row(engagement_id, tenant_id)` then `list_availability(contractor_id)` | 404 cross-tenant; 200 same tenant |
| Authz | `contractors.read` on availability GET (same as opening the card). Visits tab still needs `visits.read` | 403 without `contractors.read` |
| Write amplification | No PUT/POST on availability from staff | no route |
| Least privilege | Do not require `shifts.read` (roster overlay loads every contractor) | card works with `contractors.read` + `visits.read` |

Login/layout/tab chrome cross **no** new trust boundary.

---

## Slice 0 — Shared tab chrome + wider PageContent

### Task 1: `SubjectTabBar` + `PageContentWidth.wide`

**Files:**
- Create: `frontend/lib/shared/widgets/subject_tab_bar.dart`
- Create: `frontend/test/shared/widgets/subject_tab_bar_test.dart`
- Modify: `frontend/lib/core/responsive/page_content.dart` (add `wide`)
- Modify: `frontend/lib/features/clients/views/client_detail_view.dart` (use `SubjectTabBar`)
- Test: existing `frontend/test/features/clients/client_detail_view_tabs_test.dart` must still pass with the same `ValueKey('client-detail-tab-$i')`

- [ ] **Step 1: Write the failing test**

```dart
// frontend/test/shared/widgets/subject_tab_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/widgets/subject_tab_bar.dart';

void main() {
  testWidgets('selecting a chip reports the index', (tester) async {
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubjectTabBar(
            labels: const ['Overview', 'Credentials'],
            index: index,
            keyPrefix: 'contractor-detail-tab',
            onChanged: (i) => index = i,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('contractor-detail-tab-0')), findsOneWidget);
    await tester.tap(find.text('Credentials'));
    await tester.pump();
    expect(index, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/shared/widgets/subject_tab_bar_test.dart`
Expected: FAIL compiling (`SubjectTabBar` not found)

- [ ] **Step 3: Write minimal implementation**

```dart
class SubjectTabBar extends StatelessWidget {
  const SubjectTabBar({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.keyPrefix = 'subject-tab',
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('$keyPrefix-$i'),
                label: Text(labels[i]),
                selected: index == i,
                onSelected: (_) => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}
```

In `page_content.dart` add:

```dart
enum PageContentWidth {
  narrow,
  workflow,
  /// Roster / wide boards (~1200). Reuses [Breakpoints.maxContent].
  wide,
}

double get _maxWidth => switch (width) {
  PageContentWidth.narrow => Breakpoints.narrowContent,
  PageContentWidth.workflow => Breakpoints.workflowContent,
  PageContentWidth.wide => Breakpoints.maxContent,
};
```

Replace the client detail chip `Row` with:

```dart
SubjectTabBar(
  labels: _tabLabels,
  index: tab,
  keyPrefix: 'client-detail-tab',
  onChanged: (i) => controller.tabIndex.value = i,
)
```

- [ ] **Step 4: Run tests**

```bash
cd frontend && flutter test \
  test/shared/widgets/subject_tab_bar_test.dart \
  test/features/clients/client_detail_view_tabs_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/shared/widgets/subject_tab_bar.dart \
  frontend/test/shared/widgets/subject_tab_bar_test.dart \
  frontend/lib/core/responsive/page_content.dart \
  frontend/lib/features/clients/views/client_detail_view.dart
git commit -m "$(cat <<'EOF'
Extract SubjectTabBar and add PageContentWidth.wide.

EOF
)"
```

(Commit in the `frontend` git root; backend is a separate repo.)

---

## Slice 1 — Contractor card tabs + full-width lifecycle

### Task 2: Tab shell on `WorkforceDetailView`

**Files:**
- Modify: `frontend/lib/features/engagements/controllers/workforce_controller.dart`
- Modify: `frontend/lib/features/engagements/views/workforce_detail_view.dart`
- Test: `frontend/test/features/engagements/workforce_detail_tabs_test.dart`

Locked tab order (product, 2026-08-19):

0. Overview  
1. Credentials  
2. Visits  
3. Schedule  

- [ ] **Step 1: Write the failing test**

Mirror [client_detail_view_tabs_test.dart](../../../test/features/clients/client_detail_view_tabs_test.dart): put `WorkforceController` with a mock engagement, pump `WorkforceDetailView`, assert keys `contractor-detail-tab-0..3`, Overview selected, Lifecycle visible, “No upcoming visits.” not on Overview.

Stub `getContractorProfilePhoto` like the client photo stub. `Get.arguments` must be the `EngagementOut` (the view reads `Get.arguments`).

```dart
expect(find.byKey(const ValueKey('contractor-detail-tab-0')), findsOneWidget);
expect(find.text('Overview'), findsWidgets);
expect(find.text('Lifecycle'), findsOneWidget);
expect(find.text('No upcoming visits.'), findsNothing);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/features/engagements/workforce_detail_tabs_test.dart`
Expected: FAIL (no tab keys)

- [ ] **Step 3: Implement tab shell**

On `WorkforceController`:

```dart
final tabIndex = 0.obs;
static const tabOverview = 0;
static const tabCredentials = 1;
static const tabVisits = 2;
static const tabSchedule = 3;
```

In `openDetail`, set `tabIndex.value = tabOverview`.

Rebuild `WorkforceDetailView` like `ClientDetailView`:

- `Column`: error, eligibility, centered `ProfilePhotoEditor` + name, `SubjectTabBar` (`keyPrefix: 'contractor-detail-tab'`), `Expanded` → `ListView` → `PageContent` → `_tabContent(tab)`
- Overview: status row, Lifecycle (stretch column), `EngagementRateBandsSection`
- Credentials / Visits / Schedule: placeholders until later tasks (`const SizedBox.shrink()` is fine only if tests for those tabs land in the same slice — prefer a Credentials placeholder with “Review credentials” in Task 4)

Lifecycle: replace `Wrap` with:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final child in actions)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: child,
      ),
  ],
)
```

Each `_actionButton` / `OutlinedButton` uses `style: … minimumSize: const Size.fromHeight(48)`.

Remove Required documents from Overview (Task 3 moves them). Until Task 3 ships, Overview may still show them — **do not** leave them on Overview after Task 3.

- [ ] **Step 4: Run tests**

```bash
cd frontend && flutter test \
  test/features/engagements/workforce_detail_tabs_test.dart \
  test/features/engagements/workforce_detail_ended_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Add contractor card tabs matching the client card chrome.

EOF
)"
```

---

## Slice 2 — Required documents on review + stretch credential actions

### Task 3: `RequiredDocCategoriesEditor` on review

**Files:**
- Create: `frontend/lib/features/engagements/widgets/required_doc_categories_editor.dart`
- Modify: `frontend/lib/features/credentials/views/staff_credential_review_view.dart`
- Modify: `frontend/lib/features/credentials/controllers/staff_credential_review_controller.dart`
- Modify: `frontend/lib/features/engagements/controllers/workforce_controller.dart` (`openCredentialReview` args)
- Modify: `frontend/lib/features/engagements/views/workforce_detail_view.dart` (Credentials tab CTA only)
- Test: `frontend/test/features/credentials/staff_credential_review_view_test.dart`
- Test: `frontend/test/features/engagements/required_doc_categories_editor_test.dart`

Copy (locked):

> Choose which certificates this worker must submit. Saving updates the requirements for this engagement. It does not accept or reject files.

- [ ] **Step 1: Write failing tests**

Editor widget test: pump with two `CredentialCategory` chips, tap one, expect `onToggle` called.

Review view test: pass `arguments: {'contractorId': 'contractor-1', 'engagementId': 'engagement-1', 'requiredCategories': ['first_aid'], 'canEditRequiredDocs': true}`. After load, expect the helper sentence above and `Save certificates`. Ended/cannot-manage: `canEditRequiredDocs: false` shows read-only labels, no Save.

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (copy not on review screen)

- [ ] **Step 3: Implement**

`RequiredDocCategoriesEditor` is the chip `Wrap` currently in `workforce_detail_view.dart` (lines 104–139) plus the helper `Text` above. `canEdit && !isEnded` shows chips + full-width `OutlinedButton` “Save certificates”; else comma-separated labels.

`StaffCredentialReviewController`:

```dart
final requiredCategories = <String>{}.obs;
final catalogCategories = <CredentialCategory>[].obs;

void toggleRequiredCategory(String code) { … same as WorkforceController.toggleDetailCategory }

Future<void> saveRequiredDocCategories() async {
  if (!canManage || _engagementId == null) return;
  // call _engagementsRepository.replaceRequiredDocCategories
  // if Get.isRegistered<WorkforceController>(), update items + selected
}
```

`canManage` = `contractors.manage`. Hide editor writes when engagement is ended: pass `isEnded` in arguments (`openCredentialReview`).

`openCredentialReview`:

```dart
arguments: {
  'contractorId': engagement.contractorId,
  'engagementId': engagement.id,
  'requiredCategories': engagement.requiredDocCategories.map((c) => c.category).toList(),
  'canEditRequiredDocs': canManage && !engagement.isEnded,
  'isEnded': engagement.isEnded,
},
```

Place the editor **above** the intro paragraph and **above** Load credentials.

Credentials tab on the card:

```dart
const Text(
  'Review submitted certificates. Required document types are edited on the review screen.',
);
if (!current.isEnded)
  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () => controller.openCredentialReview(current),
      icon: const Icon(Icons.badge_outlined),
      label: const Text('Review credentials'),
    ),
  );
```

Button `minimumSize: Size.fromHeight(48)`.

- [ ] **Step 4: Run tests**

```bash
cd frontend && flutter test \
  test/features/credentials/staff_credential_review_view_test.dart \
  test/features/engagements/required_doc_categories_editor_test.dart \
  test/features/engagements/workforce_detail_ended_test.dart
```

Expected: PASS (existing reject-reason test still finds the picker)

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Move required-document editing onto credential review.

EOF
)"
```

### Task 4: Full-width Load / View / Download

**Files:**
- Modify: `frontend/lib/features/credentials/views/staff_credential_review_view.dart` (remove `Align` around Load credentials)
- Modify: `frontend/lib/features/credentials/widgets/evidence_document_actions.dart`
- Test: `frontend/test/features/credentials/evidence_document_actions_test.dart`

- [ ] **Step 1: Extend evidence test**

```dart
testWidgets('View and Download share the row equally', (tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 400));
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: EvidenceDocumentActions(
            documents: [_doc()],
            onView: (_) {},
            onDownload: (_) {},
          ),
        ),
      ),
    ),
  );
  final view = tester.getSize(find.widgetWithText(OutlinedButton, 'View'));
  final download = tester.getSize(find.widgetWithText(OutlinedButton, 'Download'));
  expect((view.width - download.width).abs() < 1, true);
  expect(view.width > 140, true);
});
```

- [ ] **Step 2: Run to see FAIL** (Wrap does not equal-fill)

- [ ] **Step 3: Replace Wrap with**

```dart
EqualFillRow(
  children: [
    if (showView)
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: isBusy ? null : () => onView(document),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('View'),
        ),
      ),
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isBusy ? null : () => onDownload(document),
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('Download'),
      ),
    ),
  ],
)
```

When `showView: false`, single Download fills the row (`EqualFillRow` one-child behavior).

Load credentials: drop `Align`; parent `Column` is already `stretch`. `minimumSize: Size.fromHeight(48)`.

- [ ] **Step 4: Run** `flutter test test/features/credentials/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Stretch credential review actions across the content width.

EOF
)"
```

---

## Slice 3 — Visits tab (staff `contractor_id` filter)

### Task 5: `GET /v1/visits?contractor_id=`

**Files:**
- Modify: `backend/timesheet-backend/app/modules/jobs/router.py` (`list_visits`)
- Modify: `frontend/lib/features/visits/data/datasources/visits_remote_datasource.dart`
- Modify: `frontend/lib/features/visits/data/repositories/visits_repository.dart`
- Test: `backend/timesheet-backend/tests/jobs/test_list_visits_contractor_filter.py` (copy [test_list_visits_client_filter.py](../../../../backend/timesheet-backend/tests/jobs/test_list_visits_client_filter.py))

`list_visits` in service already supports `contractor_id`. The gap is the **router**: staff never passes it.

- [ ] **Step 1: Write failing pytest**

```python
def test_list_visits_filters_by_contractor_id(client: TestClient, db_conn):
    fx = asyncio.run(_seed_two_contractor_visits(db_conn))
    tok = _token(fx["admin_id"], fx["tenant_id"], ["auth.session", "visits.read"])
    resp = client.get(
        f"/v1/visits?contractor_id={fx['contractor_a']}",
        headers={"Authorization": f"Bearer {tok}"},
    )
    assert resp.status_code == 200
    ids = {row["contractor_id"] for row in resp.json()}
    assert ids == {str(fx["contractor_a"])}


def test_list_visits_foreign_contractor_id_returns_empty(...):
    # other tenant's contractor UUID → []


def test_list_visits_contractor_actor_ignores_query_contractor_id(...):
    # actor_type contractor, query contractor_id = other worker → only JWT worker's visits
```

Seed like the client-filter test: one tenant, two contractors, one visit each.

- [ ] **Step 2: Run** `DOTENV_PATH=../.env .venv/bin/pytest tests/jobs/test_list_visits_contractor_filter.py -q`
Expected: FAIL (filter ignored; both visits returned)

- [ ] **Step 3: Router change** (`list_visits` in `jobs/router.py`)

Add `contractor_id: UUID | None = Query(default=None)`.

```python
staff_contractor_id = contractor_id if payload.get("actor_type") == "tenant_member" else None

if payload.get("actor_type") == "contractor" and not has_permission(perms, "visits.manage"):
    # existing JWT resolve; do not use query contractor_id
    ...
    return await service.list_visits(..., contractor_id=contractor_filter, ...)

async with pool.acquire() as conn:
    return await service.list_visits(
        ...,
        contractor_id=staff_contractor_id,
        ...
    )
```

- [ ] **Step 4: Run pytest** — Expected: PASS

- [ ] **Step 5: Flutter query param**

```dart
Future<List<VisitOut>> listVisits({
  ...
  String? contractorId,
}) async {
  ...
  if (contractorId != null && contractorId.isNotEmpty)
    'contractor_id': contractorId,
}
```

Same named arg on the repository.

- [ ] **Step 6: Commit backend + frontend query plumbing** (two repos → two commits)

```bash
# backend
git commit -m "$(cat <<'EOF'
Allow staff to filter GET /v1/visits by contractor_id.

EOF
)"

# frontend
git commit -m "$(cat <<'EOF'
Pass contractorId through VisitsRepository.listVisits.

EOF
)"
```

### Task 6: Visits tab UI

**Files:**
- Modify: `frontend/lib/features/clients/widgets/client_detail_visits_section.dart` (`showPast`, default `true`)
- Modify: `frontend/lib/features/clients/utils/client_visit_windows.dart` (re-export)
- Create: `frontend/lib/features/visits/utils/visit_windows.dart` (move `partitionClientVisits` + window constants)
- Modify: `frontend/lib/features/engagements/controllers/workforce_controller.dart` (optional `VisitsRepository?`, load/partition)
- Modify: `frontend/lib/features/engagements/bindings/engagements_binding.dart`
- Modify: `frontend/lib/features/engagements/views/workforce_detail_view.dart`
- Test: `frontend/test/features/engagements/workforce_detail_visits_tab_test.dart`

- [ ] **Step 1: Failing widget tests**

Tap `contractor-detail-tab-2`. Expect `Upcoming`. Expect `Past` **nothing** (`showPast: false`). Stub `listVisits(contractorId: e.contractorId, …)` with one future scheduled visit and one completed visit; expect the future job title on Visits, **not** the completed title.

Missing `visits.read`: stub session permission false for visits/jobs; expect `Visits require visits.read`, no `listVisits` call.

*(Eng review D4: empty-state copy, not a blank tab.)*

- [ ] **Step 2: Run — FAIL** (placeholder tab)

- [ ] **Step 3: Implement**

Move `partitionClientVisits`, `ClientVisitPartition`, and the 30/30/100 constants to `frontend/lib/features/visits/utils/visit_windows.dart`. Re-export them from `client_visit_windows.dart` so `clients_controller.dart` and existing tests keep compiling.

*(Eng review D3: workforce/clients depend on visits, not the reverse.)*

Add `showPast = true` to `ClientDetailVisitsSection`. When false, omit the Past header/tiles (keep Upcoming, which includes current `checked_in` via `partitionClientVisits`).

`WorkforceController` constructor: `VisitsRepository? visits` (same optional pattern as `ClientsController`). Binding: `Get.find<VisitsRepository>()` only if registered; otherwise `EngagementsBinding` should `lazyPut` visits remote/repo the same way `ClientsBinding` does — **ensure visits datasource is registered** rather than silently skipping. Copy the `VisitsRemoteDataSource` / `VisitsRepository` `lazyPut` from the visits binding into `EngagementsBinding.ensureShared` if not already global.

`loadDetailVisits()`:

```dart
final now = DateTime.now().toUtc();
final list = await visitsRepo.listVisits(
  contractorId: engagement.contractorId,
  from: now.subtract(clientVisitLookback),
  to: now.add(clientVisitLookahead),
  limit: clientVisitFetchLimit,
);
final parts = partitionClientVisits(list, now: now);
```

Guard with `visits.read` / `visits.manage` / `jobs.manage` like clients. Call `loadDetailVisits()` and `loadDetailAvailability()` together on the **first** select of Visits or Schedule (`ever(tabIndex)` or a `_detailExtrasLoaded` flag). Do **not** fetch in `openDetail`. Reset the flag when opening another engagement.

*(Eng review D5: Overview stays cheap.)*

`openVisitDetail` → `AppRoutes.staffVisitDetail` with `skipBoardLoad: true` (copy clients).

Reuse lookback/limit constants from `visit_windows.dart` (do not duplicate 30/30/100).

- [ ] **Step 4: Run Flutter tests**

```bash
cd frontend && flutter test test/features/engagements/ test/features/clients/client_detail_support_section_test.dart
```

Expected: PASS (client Past still visible)

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Show this worker's current and upcoming visits on the contractor card.

EOF
)"
```

---

## Slice 4 — Schedule tab (availability + day agenda)

### Task 7: `GET /v1/engagements/{id}/availability`

**Files:**
- Modify: `backend/timesheet-backend/app/modules/engagements/router.py`
- Modify: `backend/timesheet-backend/app/modules/engagements/service.py`
- Modify: `backend/timesheet-backend/app/core/constants/api_paths` N/A (Flutter `ApiPaths`)
- Test: `backend/timesheet-backend/tests/engagements/test_engagement_availability.py`

Response: list of `{day_of_week, start_time, end_time}` (workforce overlay shape — no rule UUIDs). Map from `contractor_schedule.service.list_availability`.

- [ ] **Step 1: Failing pytest**

Happy: seed engagement + two availability rules → 200, two rows, days match.  
Ended engagement: still 200 (read-only roster context).  
Cross-tenant engagement id: 404.  
Missing `contractors.read`: 403.  
No rules: `[]`.

- [ ] **Step 2: Run — FAIL** (404 route)

- [ ] **Step 3: Service**

```python
async def list_engagement_availability(
    conn, *, engagement_id: UUID, tenant_id: UUID
) -> list[AvailabilityRuleOut]:  # workforce.schemas.AvailabilityRuleOut
    row = await _get_engagement_row(conn, engagement_id=engagement_id, tenant_id=tenant_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Engagement not found")
    from app.modules.contractor_schedule import service as schedule_service
    rules = await schedule_service.list_availability(
        conn, contractor_id=row["contractor_id"]
    )
    return [
        AvailabilityRuleOut(
            day_of_week=r.day_of_week,
            start_time=r.start_time,
            end_time=r.end_time,
        )
        for r in rules
    ]
```

Router:

```python
@router.get(
    "/engagements/{engagement_id}/availability",
    response_model=list[WorkforceAvailabilityRuleOut],
)
async def get_engagement_availability(
    engagement_id: UUID,
    pool: Annotated[asyncpg.Pool, Depends(db_pool)],
    payload: Annotated[dict, Depends(require_permission("contractors.read"))],
) -> list[WorkforceAvailabilityRuleOut]:
    tenant_id = tenant_id_from_payload(payload)
    async with pool.acquire() as conn:
        return await service.list_engagement_availability(
            conn, engagement_id=engagement_id, tenant_id=tenant_id
        )
```

Alias the overlay schema import to avoid clashing with contractor_schedule `AvailabilityRuleOut`.

- [ ] **Step 4: pytest PASS**

- [ ] **Step 5: Flutter API**

`ApiPaths.engagementAvailability(id) => '${engagement(id)}/availability'`  
`EngagementsRemoteDataSource.listAvailability(engagementId)` → `List<overlay.AvailabilityRuleOut>`  
repository wrapper.

- [ ] **Step 6: Commit backend then frontend client**

### Task 8: `AvailabilityRulesReadout` + `VisitDayAgenda` on Schedule tab

**Files:**
- Create: `frontend/lib/shared/widgets/availability_rules_readout.dart`
- Create: `frontend/lib/shared/widgets/visit_day_agenda.dart`
- Create: tests under `frontend/test/shared/widgets/`
- Modify: workforce detail view + controller (`loadDetailSchedule`)

- [ ] **Step 1: Widget tests**

Readout: empty → `No weekly availability set.`  
Readout: Monday 09:00–17:00 → finds `Mon` and `09:00–17:00` (format `HH:mm`, strip seconds).

Agenda: two visits on different local days → two day headers; tap calls `onOpen`.

Integration: tap `contractor-detail-tab-3`. Stub one completed visit + one future visit + empty availability. Expect both titles on Timetable; Visits tab still hides the completed row. Expect `No weekly availability set.`

Availability 403: stub `listAvailability` throwing `AppFailure`; expect the error string in an error box on Schedule, timetable still shows visits if `listVisits` succeeded.

*(Eng review D4.)*

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement widgets**

`AvailabilityRulesReadout`: sort by `dayOfWeek`; weekday labels `['Mon',…,'Sun']` (0=Monday, same as overlay). Empty list → muted sentence.

`VisitDayAgenda`:

```dart
class AgendaVisit {
  const AgendaVisit({
    required this.start,
    required this.end,
    required this.title,
    required this.status,
    required this.onOpen,
  });
  final DateTime start, end;
  final String title, status;
  final VoidCallback onOpen;
}
```

Group by local `yyyy-MM-dd`. Reuse the contractor schedule day-header look (weekday + date) but do **not** import `ContractorScheduleView` privates.

Schedule tab body:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const Text('Availability', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
    const SizedBox(height: 8),
    AvailabilityRulesReadout(rules: controller.detailAvailability.toList()),
    const SizedBox(height: 24),
    const Text('Timetable', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
    const SizedBox(height: 8),
    VisitDayAgenda(
      visits: [
        for (final v in [
          ...controller.upcomingVisits,
          ...controller.pastVisits,
        ])
          AgendaVisit(
            start: v.scheduledStart,
            end: v.scheduledEnd,
            title: v.jobTitle ?? 'Visit',
            status: v.status,
            onOpen: () => controller.openVisitDetail(v),
          ),
      ],
    ),
  ],
)
```

Same `listVisits` window as the Visits tab. **Visits tab** shows upcoming/current only (`showPast: false`). **Timetable** gets the full non-cancelled partition (upcoming + past in that window) so completed visits still appear on the day agenda. Do not add a second fetch. If visits failed to load, show that error on Schedule too.

*(Eng review D2: full window on timetable, not upcoming-only, not a 7-day extra API.)*

`loadDetailAvailability()` on openDetail (parallel with visits). 403/404 → `scheduleError` inline.

- [ ] **Step 4: Tests**

```bash
cd frontend && flutter test \
  test/shared/widgets/ \
  test/features/engagements/
```

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Show read-only availability and a visit timetable on the contractor card.

EOF
)"
```

---

## Slice 5 — Roster centered width

### Task 9: Wrap roster board in `PageContent.wide`

**Files:**
- Modify: `frontend/lib/features/visits/views/staff_visits_board_view.dart`
- Test: `frontend/test/features/visits/staff_visits_board_view_test.dart`

Previous trial plan left the board full-bleed. V2 overrides: **center + cap**. Use `PageContentWidth.wide` (1200 = `Breakpoints.maxContent`). The week grid already scrolls horizontally inside; capping the outer column is enough. Do not invent 1440 unless 1200 clips the name + 7×150px day columns in tests — if a test or visual check shows clip, bump **only** `Breakpoints.maxContent` consumers via `PageContent.wide`, not a new enum value.

- [ ] **Step 1: Test**

Pump board at 1600px width. Find the filter `DropdownButtonFormField` (Client). Assert its center X is near 800 (screen center), not left-aligned at ~200.

Implementation sketch:

```dart
final clientField = find.byType(DropdownButtonFormField<String>).first;
final center = tester.getCenter(clientField);
expect(center.dx, closeTo(800, 80));
```

If the existing board test uses a phone size, add a dedicated `testWidgets('wide roster content is centered', …)` with `setSurfaceSize(Size(1600, 900))`.

- [ ] **Step 2: FAIL** (full-bleed; Client dropdown sits left)

- [ ] **Step 3: Wrap the `Column` children that are the board chrome + `Expanded` grid**

```dart
body: Obx(() {
  return Align(
    alignment: Alignment.topCenter,
    child: PageContent(
      width: PageContentWidth.wide,
      child: Column( /* existing column */ ),
    ),
  );
})
```

`PageContent` already uses `MaxWidthBox` + `topCenter`. Put it as the `Scaffold.body` child. Keep FAB/AppBar full width.

If `PageContent` inside `Scaffold.body` without an `Expanded` parent fails (unbounded height): wrap as

```dart
Column(
  children: [
    PageContent(width: PageContentWidth.wide, child: filterBlock),
    Expanded(
      child: PageContent(
        width: PageContentWidth.wide,
        child: rosterGrid,
      ),
    ),
  ],
)
```

Filters and grid must share the same max width so they line up.

- [ ] **Step 4: Run** `flutter test test/features/visits/staff_visits_board_view_test.dart`
Expected: PASS (client/status `EqualFillRow` still works)

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Center the roster board on PageContent.wide.

EOF
)"
```

---

## Test Plan & Verification

**Coverage target:** Every new public widget (`SubjectTabBar`, `RequiredDocCategoriesEditor`, `AvailabilityRulesReadout`, `VisitDayAgenda`) has a widget test; every new/changed public API (`GET visits?contractor_id`, `GET engagements/{id}/availability`) has happy + IDOR + authz tests; contractor card tab isolation matches the client-card tab test.

**Critical paths (must pass before ship):**
- Open contractor card → Overview (lifecycle + rates) → Credentials → Review credentials shows required-doc editor at top → save chips → categories persist (`PUT` already exists)
- Visits tab lists this contractor’s upcoming/current visits only
- Schedule tab shows availability windows + day-grouped visits for the **full fetch window** (completed included)
- Roster at 1600px: filters/grid centered, not full-bleed
- Ended engagement: no Review CTA, no required-doc Save, no new rates (existing ended tests)
- Overview open does **not** call visits or availability APIs

**Edge cases & error paths:**
- Staff `contractor_id` for another tenant → `[]` → covered by pytest
- Contractor JWT + query `contractor_id` of someone else → ignored → pytest
- Availability GET other tenant → 404
- No `visits.read` → Visits tab “Visits require visits.read” (`hasVisitsAccess: false`)
- No availability rules → muted empty copy
- `showView: false` → Download still full width
- Reject empty certificate + reason picker (existing tests must stay green)

**Regression guards:**
- Client tabs Overview → Support → Locations → Contacts → Details → `client_detail_view_tabs_test.dart`
- Client visits still show Past → `client_detail_support_section_test.dart`
- Ended workforce review/rates → `workforce_detail_ended_test.dart`
- Evidence hide View → `evidence_document_actions_test.dart`
- Roster client+status row → `staff_visits_board_view_test.dart`

**Verification commands:**

- Unit (Flutter):

```bash
cd frontend && flutter test \
  test/shared/widgets/ \
  test/features/engagements/ \
  test/features/credentials/ \
  test/features/clients/client_detail_view_tabs_test.dart \
  test/features/clients/client_detail_support_section_test.dart \
  test/features/visits/staff_visits_board_view_test.dart
```

Expected: all pass

- Unit (backend):

```bash
cd backend/timesheet-backend && DOTENV_PATH=../.env .venv/bin/pytest \
  tests/jobs/test_list_visits_contractor_filter.py \
  tests/jobs/test_list_visits_client_filter.py \
  tests/engagements/test_engagement_availability.py \
  tests/engagements/test_required_doc_categories.py -q
```

Expected: all pass

- Coverage: new Dart files in `lib/shared/widgets/subject_tab_bar.dart`, `availability_rules_readout.dart`, `visit_day_agenda.dart`, `required_doc_categories_editor.dart` — every public constructor branch (empty, one child, edit vs read-only) has a test. New Python functions: 100% of branches in `list_engagement_availability` and the new `list_visits` contractor_id gate.

- E2E: not required (staff widget + API tests cover the journeys)

**Acceptance criteria (from spec):**
- [ ] Contractor card is a tab view like the client card → Task 2 / `workforce_detail_tabs_test`
- [ ] Credentials tab exists; required documents live at top of Review Credentials with clearer edit copy → Task 3
- [ ] Lifecycle, Load credentials, View/Download fill content width → Tasks 2 and 4
- [ ] Current + upcoming visits on a contractor-card tab → Tasks 5–6
- [ ] Timetable + availability on a contractor-card tab → Tasks 7–8
- [ ] Roster content is width-capped and centered → Task 9

---

## Parallelization

| Step | Modules | Depends on |
|------|---------|------------|
| SubjectTabBar + PageContent.wide | `frontend/lib/shared`, `page_content`, client detail | — |
| Contractor tab shell + stretch lifecycle | `engagements/views`, `workforce_controller` | SubjectTabBar |
| Required docs on review + evidence EqualFillRow | `credentials`, editor widget | tab shell (Credentials CTA) |
| visits?contractor_id | `jobs/router`, visits DS | — |
| Visits tab UI | `workforce_controller`, visits section | contractor_id API + tab shell |
| availability GET | `engagements` backend | — |
| Schedule tab UI | shared readout/agenda, workforce | availability GET + visits load |
| Roster PageContent.wide | `staff_visits_board_view` | PageContent.wide enum |

Lane A (frontend chrome): Task 1 → 2 → 3 → 4  
Lane B (visits API): Task 5, then 6 after A has tab shell  
Lane C (availability API): Task 7, then 8 after A + visits load  
Lane D (roster): Task 9 after Task 1 enum  

Lanes B and C are separate git repos on the backend side and can start in parallel with A.

Conflict flag: Tasks 2, 3, 6, 8 all edit `workforce_detail_view.dart` / `workforce_controller.dart` — keep those sequential in one lane after the tab shell exists.

---

## What already exists

- Client card tab chrome (`ClientDetailView` + ChoiceChips) — reused via `SubjectTabBar`
- `ClientDetailVisitsSection` + `partitionClientVisits` (moved to `visits/utils`)
- `GET /v1/visits` + `list_visits(..., contractor_id=)` in service; router just did not expose staff query
- `contractor_schedule.service.list_availability` — staff GET maps it, no new SQL
- `GET /v1/workforce/roster-overlay` — **not** used on the card (loads every contractor, needs `shifts.read`)
- `PUT /v1/engagements/{id}/required-doc-categories` — already shipped; editor moves to review
- `EqualFillRow`, `PageContent`, `Breakpoints.maxContent` (1200)
- Contractor self-serve Schedule (`contractor-me/timetable|availability`) — stays contractor-JWT; staff does not call it

## NOT in scope (review)

- Staff PUT/POST availability or leave
- New timetable HTTP API
- `client_name` on `VisitOut` — captured as TODOS.md **T13**
- Splitting `WorkforceController` into a detail controller
- Changing day-column width on the roster grid
- `TODOS.md` T7/T9/T10/T12, address autocomplete, horizon TZ/cron

## Failure modes

| Path | Production failure | Test | User sees |
|------|--------------------|------|-----------|
| `GET /visits?contractor_id=` other tenant | empty list | pytest foreign UUID | “No upcoming visits.” |
| Contractor spoofs query `contractor_id` | ignored | pytest contractor actor | own visits only |
| Availability GET 404/403 | HTTP error | pytest + Flutter 403 box | inline error on Schedule |
| Visits fetch timeout | Dio error | existing AppFailure mapping | `visitsError` on Visits |
| Lazy load never fires | tab empty | widget tests tap tab 2/3 | would be silent — **tests required** |
| `PageContent` unbounded height on roster | layout exception | board widget test | crash — fallback two-`PageContent` layout in Task 9 |
| Required-doc save on ended | 409 | existing API test; UI hides Save | no write |

No critical gap of silent + untested + no handling after D4/D5 tests.

## Implementation Tasks

Synthesized from this review. Run with the plan tasks 1–9; checkbox as you ship.

- [ ] **T1 (P1, human: ~15min / CC: ~5min)** — Timetable uses full visit window — D2
  - Surfaced by: Architecture — upcoming-only would drop completed visits
  - Files: `workforce_detail_view.dart`, `workforce_detail_visits_tab_test.dart` / schedule integration test
  - Verify: completed visit on Schedule, not on Visits Past
- [ ] **T2 (P2, human: ~25min / CC: ~8min)** — Move visit partition helpers to `visits/utils` — D3
  - Surfaced by: Code quality — workforce must not import `clients/utils`
  - Files: `visit_windows.dart`, `client_visit_windows.dart` re-export
  - Verify: existing client visit tests still pass
- [ ] **T3 (P1, human: ~30min / CC: ~8min)** — Flutter empty/error states — D4
  - Surfaced by: Test review — blank tabs
  - Files: visits tab test (no `visits.read`), schedule tab test (availability 403)
  - Verify: muted copy + error box
- [ ] **T4 (P2, human: ~20min / CC: ~5min)** — Lazy-load extras — D5
  - Surfaced by: Performance — Overview paying for unused APIs
  - Files: `workforce_controller.dart`
  - Verify: `listVisits` not called until tab 2 or 3
- [ ] **T5 (P3, human: ~2h / CC: ~25min)** — `client_name` on visits — deferred T13
  - Surfaced by: TODOS — YAML “visits of the client”
  - Files: `jobs/service.py` `_VISIT_COLUMNS`, Flutter `VisitOut`
  - Verify: not this PR

## Eng review decisions

| ID | Choice |
|----|--------|
| D1 | Keep four extracts + both APIs |
| D2 | Timetable = full visit window |
| D3 | Move partition helpers to `visits/utils` |
| D4 | Flutter tests for no `visits.read` and availability 403 |
| D5 | Lazy-load visits + availability on first Visits/Schedule tap |
| D6 | TODOS.md T13 `client_name` on VisitOut |
| D7 | Skip staff edit of availability |

---

## GSTACK REVIEW REPORT

- **Skill:** plan-eng-review
- **Status:** clean
- **Mode:** FULL_REVIEW
- **Scope:** accepted as-is (four shared widgets + two APIs); findings folded into the plan
- **Architecture:** 1 issue (timetable visit set) → D2 A
- **Code quality:** 1 issue (helper home) → D3 A
- **Tests:** diagram produced; 2 widget error-path gaps → D4 A
- **Performance:** 1 issue (eager fetch) → D5 A
- **Unresolved decisions:** 0
- **Critical gaps:** 0
- **TODOS.md:** T13 added; staff availability edit skipped

