# Client Detail Nav Hydration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After finishing client onboarding, staff always land on a loaded client detail screen — never “Client not found.”

**Architecture:** **Hydration-by-id is the source of truth** (survives `ClientsBinding` recreating the controller). Always navigate with `parameters: {'id': clientId}` (and `arguments: updated`). On detail entry, `ensureDetailHydratedFromRoute()` loads via `openDetailById` when `selected` is null. Optionally also set `selected` before navigate when the same `ClientsController` instance survives. Prefer `Get.offNamed` over `offAllNamed` so the staff shell stack stays; do **not** rely on in-memory `selected` alone — that is the P0 bug.

**Tech Stack:** Flutter, GetX, existing `ClientsRepository.getClient`, widget tests with `GetMaterialApp` + mocktail.

**Spec:** `docs/client-detail-navigation-todo.md` §1 + §2 client-id risk + checklist §4.

**Trust boundary:** No new endpoints. Hydration only reuses authenticated `getClient(id)`. Reject empty/missing id with existing empty-state UI.

**Design principles:**
- **DRY:** Call `ClientsController.openDetailById` / extend `openDetail` — do not duplicate fetch logic in the onboarding controller.
- **SOLID:** Navigation orchestration stays in controllers; `ClientDetailView` stays a dumb view of `selected` + loading.
- **YAGNI:** Do not rebuild workforce/credential routes in this PR.

---

## File Structure

| File | Responsibility / seam |
|------|------------------------|
| `frontend/lib/features/clients/controllers/client_onboarding_controller.dart` | `finishOnboarding` — after patch, hand off to `ClientsController` then navigate with id param |
| `frontend/lib/features/clients/controllers/clients_controller.dart` | `openDetail`, `openDetailById`, new `ensureDetailHydratedFromRoute()` — single place that loads by id |
| `frontend/lib/features/clients/bindings/clients_binding.dart` | Unchanged pattern; fresh controller must hydrate from route |
| `frontend/lib/features/clients/views/client_detail_view.dart` | Optional: trigger hydrate once if selected null (or binding/controller onInit) |
| `frontend/test/features/clients/client_onboarding_controller_test.dart` | Extend finish → detail hydration |
| `frontend/test/features/clients/client_detail_navigation_test.dart` | Args / parameters hydrate when selected null |

---

### Task 1: Failing test — finishOnboarding hydrates ClientsController.selected

**Files:**
- Modify: `frontend/test/features/clients/client_onboarding_controller_test.dart`
- Modify: `frontend/lib/features/clients/controllers/client_onboarding_controller.dart` (later)

- [ ] **Step 1: Write the failing test**

Extend the existing widget test `finishOnboarding replaces stack with client detail route` (or add a sibling). Register a real `ClientsController` with mocked repo so `selected` can be asserted:

```dart
testWidgets(
  'finishOnboarding hydrates ClientsController.selected before detail route',
  (tester) async {
    Get.testMode = true;
    Get.reset();
    final clientsCtrl = ClientsController(
      repository: mock, // same mock as onboarding; stub getClient/list extras
      session: sessionMock,
      jobsRepository: jobsMock,
    );
    Get.put(clientsCtrl);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.staffClientOnboarding,
        getPages: [
          GetPage(
            name: AppRoutes.staffClientOnboarding,
            page: () => const SizedBox.shrink(),
          ),
          GetPage(
            name: AppRoutes.staffClientDetail,
            page: () => const SizedBox.shrink(),
            binding: BindingsBuilder(() {
              if (!Get.isRegistered<ClientsController>()) {
                Get.put(clientsCtrl);
              }
            }),
          ),
        ],
      ),
    );

    when(() => mock.getClient('client-1')).thenAnswer((_) async => _fakeClient);
    when(() => mock.patchClient(any(), any())).thenAnswer((_) async => _fakeClient);
    // stub list/load extras used by openDetailById / load() as needed:
    when(() => mock.listClients(any())).thenAnswer((_) async => [_fakeClient]);
    when(() => mock.getClientProfilePhoto(any()))
        .thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
    when(() => mock.listClientTypes()).thenAnswer((_) async => []);
    when(() => mock.getClientProfile(any()))
        .thenAnswer((_) async => const ClientProfileBundle(facts: []));
    when(() => mock.listSites(any())).thenAnswer((_) async => []);
    when(() => mock.listContacts(any())).thenAnswer((_) async => []);
    when(() => mock.listSupportPlans(any())).thenAnswer((_) async => []);

    c.dispose();
    c = _buildController(softGateConfirm: (_) async => true);
    c.client.value = _fakeClient;
    c.step.value = 6;

    expect(await c.finishOnboarding(), isTrue);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.staffClientDetail);
    expect(Get.parameters['id'], 'client-1');
    expect(clientsCtrl.selected.value?.id, 'client-1');
  },
);
```

Adapt stubs to match how `_buildController` / existing test helpers already mock `ClientsRepository`. Prefer putting a dedicated `ClientsController` in the test rather than relying on binding recreation wiping state.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd frontend && flutter test test/features/clients/client_onboarding_controller_test.dart --name "hydrates ClientsController.selected"
```

Expected: FAIL — `selected` is null and/or `parameters['id']` is missing.

- [ ] **Step 3: Commit the failing test**

```bash
git add frontend/test/features/clients/client_onboarding_controller_test.dart
git commit -m "test: assert finishOnboarding hydrates client detail selection"
```

---

### Task 2: Implement finishOnboarding handoff via openDetail pattern

**Files:**
- Modify: `frontend/lib/features/clients/controllers/client_onboarding_controller.dart` (~1553–1590)
- Modify: `frontend/lib/features/clients/controllers/clients_controller.dart` (`openDetail`)

- [ ] **Step 1: Add `openDetailAfterCreate` (or extend `openDetail`) with replace semantics**

In `clients_controller.dart`, add a method used by onboarding finish (SRP: ClientsController owns detail entry):

```dart
/// Opens client detail after onboarding (replaces current route).
Future<void> openDetailReplacing(ClientOut client) async {
  selected.value = client;
  lastInvite.value = null;
  invites.clear();
  tabIndex.value = 0;
  selectedClientTypeId.value = client.clientTypeId;
  detailPhoto.value = null;
  upcomingVisits.clear();
  pastVisits.clear();
  visitsError.value = null;
  visitsTruncated.value = false;
  profileFacts.clear();
  standingJob.value = null;
  supportPlan.value = null;
  _disposeRequirementDrafts();
  requirementDrafts.clear();

  Get.offNamed(
    AppRoutes.staffClientDetail,
    arguments: client,
    parameters: {'id': client.id},
  );
  await openDetailById(client.id);
}
```

Notes:
- Use `offNamed` (not `offAllNamed`) so Staff shell / clients list stay under the detail when possible. If product still wants a hard stack wipe, document why in the commit — default is `offNamed` per todo D4 note.
- Keep the same field resets as `openDetail` (copy from `openDetail` body; DRY by extracting `_prepareDetailState(ClientOut client)` if the duplication is >5 lines).

- [ ] **Step 2: Change `finishOnboarding` navigation**

Replace:

```dart
if (Get.isRegistered<ClientsController>()) {
  await Get.find<ClientsController>().load();
}
Get.offAllNamed(AppRoutes.staffClientDetail, arguments: updated);
```

With:

```dart
if (!Get.isRegistered<ClientsController>()) {
  Get.put(ClientsController(
    repository: Get.find(), // only if binding not available — prefer ensuring ClientsBinding ran
    session: Get.find(),
    jobsRepository: Get.find(),
  ));
}
final clients = Get.find<ClientsController>();
await clients.load();
await clients.openDetailReplacing(updated);
```

**Eng-review lock:** Never `Get.put(ClientsController(...))` inline with ad-hoc deps — let `ClientsBinding` on the detail route construct it. Always pass `parameters: {'id': id}`. If `ClientsController` is already registered, call `openDetailReplacing`; if not, only navigate with id/args and rely on Task 3 hydrate:

```dart
} else {
  if (Get.isRegistered<ClientsController>()) {
    final clients = Get.find<ClientsController>();
    await clients.load();
    await clients.openDetailReplacing(updated);
  } else {
    Get.offNamed(
      AppRoutes.staffClientDetail,
      arguments: updated,
      parameters: {'id': id},
    );
  }
}
```

Ship Task 3 in the **same PR** as Task 2 — navigate-with-id without hydrate is incomplete.

- [ ] **Step 3: Run the hydration test**

```bash
cd frontend && flutter test test/features/clients/client_onboarding_controller_test.dart --name "hydrates ClientsController.selected"
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/features/clients/controllers/client_onboarding_controller.dart \
  frontend/lib/features/clients/controllers/clients_controller.dart
git commit -m "fix: hydrate client detail after onboarding finish"
```

---

### Task 3: Hydrate detail from route id / arguments when selected is null

**Files:**
- Modify: `frontend/lib/features/clients/controllers/clients_controller.dart`
- Modify: `frontend/test/features/clients/client_detail_navigation_test.dart`
- Optionally: `frontend/lib/features/jobs/controllers/unified_support_controller.dart` — pass `parameters: {'id': c.id}` when opening client (falls out free)

- [ ] **Step 1: Write failing test**

```dart
testWidgets(
  'ClientDetailView loads by route id when selected is null',
  (tester) async {
    controller.selected.value = null;
    when(() => clients.getClient(_client.id)).thenAnswer((_) async => _client);
    // stub extras same as setUp...

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '${AppRoutes.staffClientDetail}?id=${_client.id}',
        getPages: [
          GetPage(
            name: AppRoutes.staffClientDetail,
            page: () => const ClientDetailView(),
          ),
        ],
      ),
    );
    // Ensure controller is the one under test:
    Get.put(controller);

    await controller.ensureDetailHydratedFromRoute();
    await tester.pumpAndSettle();

    expect(find.text('Client not found.'), findsNothing);
    expect(find.text(_client.fullName), findsOneWidget);
  },
);
```

If GetX query params are awkward in tests, call hydrate with an explicit id helper and separately assert `openDetail` passes parameters.

Also add:

```dart
test('ensureDetailHydratedFromRoute uses Get.arguments ClientOut', () async {
  controller.selected.value = null;
  Get.routing.args = _client; // or navigate with arguments in widget test
  await controller.ensureDetailHydratedFromRoute();
  expect(controller.selected.value?.id, _client.id);
  verify(() => clients.getClient(_client.id)).called(1);
});
```

- [ ] **Step 2: Run to fail**

```bash
cd frontend && flutter test test/features/clients/client_detail_navigation_test.dart --name "loads by route id"
```

Expected: FAIL — method missing / still shows not found.

- [ ] **Step 3: Implement hydrate**

```dart
/// Call from ClientsController.onInit or ClientDetailView first build.
Future<void> ensureDetailHydratedFromRoute() async {
  if (selected.value != null) return;

  final fromArgs = Get.arguments;
  if (fromArgs is ClientOut) {
    selected.value = fromArgs;
    await openDetailById(fromArgs.id);
    return;
  }

  final id = Get.parameters['id'];
  if (id != null && id.isNotEmpty) {
    await openDetailById(id);
  }
}
```

Wire call site — pick **one** (YAGNI):

1. Prefer `ClientsController.onInit` / end of constructor path if controller already has `onInit` override, **or**
2. In `ClientDetailView.build`, once:

```dart
if (controller.selected.value == null && !controller.isLoading.value) {
  // schedule microtask to avoid build-phase setState
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.ensureDetailHydratedFromRoute();
  });
}
```

Prefer controller `onInit` if the binding always creates the controller for the detail page.

Also update `openDetail` to pass parameters (parity with jobs):

```dart
Get.toNamed(
  AppRoutes.staffClientDetail,
  arguments: client,
  parameters: {'id': client.id},
);
```

Update `UnifiedSupportController.openClientDetailsForNdis` similarly:

```dart
await Get.toNamed(
  AppRoutes.staffClientDetail,
  arguments: c,
  parameters: {'id': c.id},
);
```

- [ ] **Step 4: Run tests**

```bash
cd frontend && flutter test test/features/clients/client_detail_navigation_test.dart
cd frontend && flutter test test/features/clients/client_onboarding_controller_test.dart --name "finishOnboarding"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/clients/controllers/clients_controller.dart \
  frontend/lib/features/clients/views/client_detail_view.dart \
  frontend/lib/features/jobs/controllers/unified_support_controller.dart \
  frontend/test/features/clients/client_detail_navigation_test.dart
git commit -m "fix: hydrate client detail from route id and arguments"
```

---

### Task 4: Optional cleanup — dead `isCreateFlow` branch

**Files:**
- Modify: `frontend/lib/features/clients/controllers/clients_controller.dart`

- [ ] **Step 1: Grep and confirm never set true**

```bash
cd frontend && grep -n "isCreateFlow" lib/features/clients
```

- [ ] **Step 2: Either delete the branch or make it call `openDetail(created)`**

If deleting, remove the flag and dead code path. If keeping, replace “set selected + openDetailById without navigate” with `await openDetail(created)`.

- [ ] **Step 3: Run clients controller tests**

```bash
cd frontend && flutter test test/features/clients/clients_controller_support_test.dart
```

- [ ] **Step 4: Commit**

```bash
git commit -am "chore: remove or repair dead isCreateFlow client save path"
```

---

### Task 5: Manual verification + mark TODO

- [ ] **Step 1: Manual smoke**

1. Staff → Clients → Add client → complete wizard (soft-skip legal OK).
2. Land on detail showing client **name** in AppBar.
3. Back returns to clients list (or shell), not a blank stack.
4. From list, open same client — still works.
5. (Web) Refresh detail URL with `?id=` — loads client or shows spinner then name.

- [ ] **Step 2: Update todo checkboxes**

In `docs/client-detail-navigation-todo.md` §4, mark P0 items `[DONE]` with date.

- [ ] **Step 3: Commit doc**

```bash
git add docs/client-detail-navigation-todo.md TODOS.md
git commit -m "docs: mark client detail nav hydration done"
```

---

## Design notes (App UI)

**Classifier:** App UI — task-focused admin.

**Information hierarchy after finish:**
1. AppBar client name (proof of success)
2. Overview tab content
3. Secondary tabs

**States:**

| Feature | Loading | Empty | Error | Success |
|---------|---------|-------|-------|---------|
| Detail after finish | Existing spinner while `isLoading` | Must not show “Client not found.” when id valid | FloatingErrorNotice from `errorMessage` | Named AppBar + tabs |
| Hydrate by id | Spinner (`selected == null && isLoading`) | “Client not found.” only after failed/missing id | Same notice | selected set |

**Journey:** Staff finishes wizard → brief load → detail. Emotional goal: relief/confirmation, not panic at “not found.”

---

## Test Plan & Verification

**Coverage target:** Every new public method (`openDetailReplacing`, `ensureDetailHydratedFromRoute`) has a unit/widget test; finishOnboarding path asserts non-null `selected` + route id param.

**Critical paths:**
- Finish onboarding → detail shows client → widget/controller test + manual smoke
- Open from list still works → existing `openDetail` tests / manual
- Fresh controller + `parameters['id']` → hydrate test

**Edge cases & error paths:**
- `getClient` fails after finish → error message, do not navigate (existing finishOnboarding behavior) → keep existing tests
- Missing id and null args → “Client not found.” → navigation test
- Soft-gate declined → no navigation → existing test

**Regression guards:**
- `finishOnboarding re-fetches client so photo_document_id is not wiped` still passes
- Care plan controller delete on client change (`openDetailById`) still passes

**Verification commands:**

```bash
cd frontend && flutter test test/features/clients/client_onboarding_controller_test.dart
cd frontend && flutter test test/features/clients/client_detail_navigation_test.dart
cd frontend && flutter test test/features/clients/client_detail_care_plan_tab_test.dart
cd frontend && flutter analyze lib/features/clients/controllers/client_onboarding_controller.dart lib/features/clients/controllers/clients_controller.dart
```

Expected: all pass; no new errors.

**Acceptance criteria:**
- [x] Finish wizard never shows “Client not found.” for a created client → Task 1–2
- [x] Route includes client id → Task 2–3
- [x] Args/id hydrate when selected null → Task 3
- [x] Regression tests green → Test Plan commands

**Shipped (2026-09-22).** Deferred: dead `isCreateFlow` cleanup (optional).


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
