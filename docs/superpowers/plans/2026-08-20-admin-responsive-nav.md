# Admin Responsive Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix staff/admin navigation pushing page content off-screen on narrow widths by switching to a bottom bar with overflow, while keeping a left rail (with overflow when needed) on wide screens — for all users, regardless of role permissions.

**Architecture:** Introduce a shared `AdaptiveNavigationShell` that branches on `Breakpoints.tablet` (1024px), matching the existing `ContractorShell` pattern. Extract overflow splitting (`NavOverflowSplit`) so bottom and rail layouts reuse the same "visible + More" logic. `StaffShell` delegates layout to the adaptive shell; `ResponsiveScaffold` remains the wide rail renderer; narrow mode uses `Scaffold` + `NavigationBar`.

**Tech Stack:** Flutter 3.x, Material 3 (`NavigationRail`, `NavigationBar`), existing `Breakpoints` / `ResponsiveDestination` in `frontend/lib/core/responsive/` and `frontend/lib/app/views/shell/`.

---

## Problem

`StaffShell` always renders a left `NavigationRail` (see comment at `staff_shell.dart:161`). On phone/tablet-portrait widths the rail consumes ~56–80px horizontally and destination labels overflow vertically (`RenderFlex OVERFLOWING` in a ~102×68px cell). Page content is squeezed and cards/controls are pushed off-screen.

Prior task AD-1 moved admin nav from crowded bottom bar to left rail. That fixed bottom-bar crowding but introduced horizontal space loss on narrow screens. This plan restores bottom nav below the tablet breakpoint while keeping left rail on wide screens.

---

## File structure

| File | Responsibility | SOLID seam |
|------|----------------|------------|
| **Create** `frontend/lib/app/views/shell/nav_overflow_split.dart` | Pure function: split destinations into visible vs overflow; keep selected item in visible set | SRP: overflow math only; no widgets |
| **Create** `frontend/lib/app/views/shell/adaptive_navigation_shell.dart` | Width branch (rail vs bottom), wires overflow More menu, delegates to rail/bottom builders | SRP: layout orchestration; depends on `NavOverflowSplit` + `ResponsiveScaffold` |
| **Modify** `frontend/lib/features/shell/staff_shell.dart` | Replace direct `ResponsiveScaffold` with `AdaptiveNavigationShell` | Shell owns nav config; shell widget owns layout |
| **Modify** `frontend/lib/app/views/shell/responsive_scaffold.dart` | Accept optional overflow destinations; render More rail destination + menu | Rail-only layout; extended, not replaced |
| **Modify** `frontend/lib/features/shell/contractor_shell.dart` | Migrate narrow branch to `AdaptiveNavigationShell` (optional Task 6 — DRY) | Reuses same overflow logic |
| **Modify** `frontend/test/features/shell/staff_shell_nav_test.dart` | Update phone-width expectation; add overflow/More tests | Regression guard |
| **Modify** `frontend/test/core/responsive/responsive_qa_test.dart` | Align `ResponsiveScaffold` rail test with adaptive shell (rail-only widget stays always-rail) | QA matrix |
| **Create** `frontend/test/app/views/shell/nav_overflow_split_test.dart` | Unit tests for split/selected-item promotion | Pure logic coverage |
| **Create** `frontend/test/app/views/shell/adaptive_navigation_shell_test.dart` | Widget tests: bottom vs rail, More menu | Layout coverage |

**Reuse (DRY — do not rebuild):**
- `Breakpoints.tablet` (1024) and `Breakpoints.phone` (600) from `breakpoints.dart`
- `ResponsiveDestination` model from `responsive_scaffold.dart`
- `ContractorShell` bottom-nav styling (`AppColors.cardBackground`, indicator alpha 0.18)
- `StaffShellNav.destinations()` / `navigateTo()` — nav data unchanged

**YAGNI — not building:**
- No `Drawer`
- No per-user breakpoint overrides (same threshold for everyone)
- No animation/transition between rail and bottom on resize (instant relayout via `LayoutBuilder`)
- No changes to route definitions or permissions

---

## Design principles

- **DRY:** One `NavOverflowSplit` used by bottom bar and rail. One `AdaptiveNavigationShell` for staff (and optionally contractor). Styling constants copied once from existing shells.
- **SOLID:** Split logic is pure and testable. `AdaptiveNavigationShell` orchestrates; `ResponsiveScaffold` renders rail; overflow menu is a small private widget in adaptive shell file.
- **YAGNI:** Overflow More only appears when `destinations.length > maxVisible`. Current staff nav has ≤6 items — bottom overflow triggers at 5+; rail overflow triggers at 7+ (constant), so rail More is latent but wired.

---

## Security (trust boundary)

This change is **UI layout only** — no new endpoints, auth, or sensitive data. No security tasks required.

---

## Constants

Add to `nav_overflow_split.dart`:

```dart
/// Max primary slots before "More" (excluding the More slot itself).
static const int maxBottomNavPrimary = 4; // + More = 5 NavigationBar destinations
static const int maxRailPrimary = 6;       // 7th+ go to More; staff currently has ≤6
```

Breakpoint for rail vs bottom: **`Breakpoints.tablet` (1024px)** — same as `ContractorShell` (`contractor_shell.dart:70`).

---

## ASCII — layout decision

```
LayoutBuilder.maxWidth
        │
        ├─ < 1024 (phone/tablet)
        │     Scaffold
        │       body: child (full width)
        │       bottomNavigationBar: NavigationBar
        │         [Home][Workforce][Clients][Roster][More?]
        │         More → ModalBottomSheet → [Payments, Settings, …]
        │
        └─ ≥ 1024 (desktop)
              Row
                NavigationRail (left)
                  [Home][Workforce][Clients][Roster][Payments][Settings][More?]
                  More → PopupMenu / anchored menu → overflow items
                VerticalDivider
                Expanded(child)
```

---

## ASCII — overflow split (More highlight when selected in overflow)

```
Input: destinations=[H,W,C,R,P,S], maxVisible=4, selectedIndex=4 (Payments)

visible=[H,W,C,R], overflow=[P,S]
NavigationBar selectedIndex → More slot (index 4)
moreSelected=true → More button shows active/indicator state

User opens More sheet → picks Settings (index 5)
→ navigate; More stays highlighted (moreSelected=true)
```

---

### Task 1: `NavOverflowSplit` pure logic

**Files:**
- Create: `frontend/lib/app/views/shell/nav_overflow_split.dart`
- Test: `frontend/test/app/views/shell/nav_overflow_split_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/views/shell/nav_overflow_split.dart';
import 'package:rostiq/app/views/shell/responsive_scaffold.dart';

ResponsiveDestination dest(String label) =>
    ResponsiveDestination(icon: Icons.circle, label: label);

void main() {
  group('NavOverflowSplit', () {
    test('returns all visible when count <= maxVisible', () {
      final all = [dest('A'), dest('B'), dest('C')];
      final result = NavOverflowSplit.split(
        destinations: all,
        selectedIndex: 1,
        maxVisible: 4,
      );
      expect(result.visible.map((d) => d.label), ['A', 'B', 'C']);
      expect(result.overflow, isEmpty);
      expect(result.moreSelected, isFalse);
    });

    test('splits overflow when count > maxVisible', () {
      final all = List.generate(6, (i) => dest('D$i'));
      final result = NavOverflowSplit.split(
        destinations: all,
        selectedIndex: 0,
        maxVisible: 4,
      );
      expect(result.visible.length, 4);
      expect(result.overflow.length, 2);
      expect(result.moreSelected, isFalse);
    });

    test('moreSelected true when selected item is in overflow', () {
      final all = [dest('H'), dest('W'), dest('C'), dest('R'), dest('P'), dest('S')];
      final result = NavOverflowSplit.split(
        destinations: all,
        selectedIndex: 4, // Payments — in overflow
        maxVisible: 4,
      );
      expect(result.visible.map((d) => d.label), ['H', 'W', 'C', 'R']);
      expect(result.overflow.map((d) => d.label), ['P', 'S']);
      expect(result.moreSelected, isTrue);
      expect(result.visibleSelectedIndex, 4); // More slot
    });

    test('moreSelected false when selected item is in visible set', () {
      final all = [dest('H'), dest('W'), dest('C'), dest('R'), dest('P'), dest('S')];
      final result = NavOverflowSplit.split(
        destinations: all,
        selectedIndex: 1, // Workforce
        maxVisible: 4,
      );
      expect(result.moreSelected, isFalse);
      expect(result.visibleSelectedIndex, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/app/views/shell/nav_overflow_split_test.dart -v`
Expected: FAIL — `NavOverflowSplit` not defined

- [ ] **Step 3: Write minimal implementation**

```dart
import 'responsive_scaffold.dart';

class NavOverflowResult {
  const NavOverflowResult({
    required this.visible,
    required this.overflow,
    required this.moreSelected,
    required this.visibleSelectedIndex,
  });

  final List<ResponsiveDestination> visible;
  final List<ResponsiveDestination> overflow;
  final bool moreSelected;
  final int visibleSelectedIndex;
}

abstract final class NavOverflowSplit {
  NavOverflowSplit._();

  static const maxBottomNavPrimary = 4;
  static const maxRailPrimary = 6;

  static bool isSelectionInOverflow({
    required List<ResponsiveDestination> destinations,
    required int selectedIndex,
    required int maxVisible,
  }) {
    if (selectedIndex < 0 || selectedIndex >= destinations.length) return false;
    if (destinations.length <= maxVisible) return false;
    return selectedIndex >= maxVisible;
  }

  static NavOverflowResult split({
    required List<ResponsiveDestination> destinations,
    required int selectedIndex,
    required int maxVisible,
  }) {
    if (destinations.length <= maxVisible) {
      return NavOverflowResult(
        visible: destinations,
        overflow: const [],
        moreSelected: false,
        visibleSelectedIndex: selectedIndex.clamp(0, destinations.length - 1),
      );
    }

    final overflow = destinations.sublist(maxVisible);
    var visible = destinations.sublist(0, maxVisible);

    var visibleSelectedIndex = selectedIndex;
    var moreSelected = false;

    if (selectedIndex >= maxVisible) {
      moreSelected = true;
      visibleSelectedIndex = maxVisible; // More slot index in NavigationBar
    } else {
      moreSelected = false;
      visibleSelectedIndex = selectedIndex;
    }

    return NavOverflowResult(
      visible: visible,
      overflow: overflow,
      moreSelected: moreSelected,
      visibleSelectedIndex: visibleSelectedIndex,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/app/views/shell/nav_overflow_split_test.dart -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/app/views/shell/nav_overflow_split.dart \
        frontend/test/app/views/shell/nav_overflow_split_test.dart
git commit -m "feat(nav): add overflow split helper for adaptive shell"
```

---

### Task 2: `AdaptiveNavigationShell` widget

**Files:**
- Create: `frontend/lib/app/views/shell/adaptive_navigation_shell.dart`
- Test: `frontend/test/app/views/shell/adaptive_navigation_shell_test.dart`

- [ ] **Step 1: Write the failing widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/views/shell/adaptive_navigation_shell.dart';
import 'package:rostiq/app/views/shell/responsive_scaffold.dart';

void main() {
  const destinations = [
    ResponsiveDestination(icon: Icons.home_outlined, label: 'Home'),
    ResponsiveDestination(icon: Icons.groups_outlined, label: 'Workforce'),
    ResponsiveDestination(icon: Icons.people_outline, label: 'Clients'),
    ResponsiveDestination(icon: Icons.event_available_outlined, label: 'Roster'),
    ResponsiveDestination(icon: Icons.payments_outlined, label: 'Payments'),
    ResponsiveDestination(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  testWidgets('narrow width uses bottom NavigationBar not rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const Text('Body'),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('wide width uses left NavigationRail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const Text('Body'),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('narrow width shows More when destinations exceed primary limit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const SizedBox(),
        ),
      ),
    );

    expect(find.text('More'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/app/views/shell/adaptive_navigation_shell_test.dart -v`
Expected: FAIL — file/class not found

- [ ] **Step 3: Write minimal implementation**

Create `adaptive_navigation_shell.dart` with:
- `LayoutBuilder` → `wide = constraints.maxWidth >= Breakpoints.tablet`
- Wide: delegate to `ResponsiveScaffold` (pass full destinations; rail handles overflow in Task 3)
- Narrow: `Scaffold(body: child, bottomNavigationBar: _BottomNavWithMore(...))`
- `_BottomNavWithMore`: uses `NavOverflowSplit.split(..., maxVisible: NavOverflowSplit.maxBottomNavPrimary)`; if overflow non-empty, append More destination (`Icons.more_horiz`); More tap → `showModalBottomSheet` listing overflow labels; map visible index back to original index before calling `onDestinationSelected`
- Reuse colors from `contractor_shell.dart:86-87`

Key index mapping helper:

```dart
int _originalIndex({
  required NavOverflowResult split,
  required int barIndex,
  required List<ResponsiveDestination> all,
}) {
  if (split.overflow.isEmpty) return barIndex;
  if (barIndex == split.visible.length) return -1; // More button — no navigate
  final label = split.visible[barIndex].label;
  return all.indexWhere((d) => d.label == label);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/app/views/shell/adaptive_navigation_shell_test.dart -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/app/views/shell/adaptive_navigation_shell.dart \
        frontend/test/app/views/shell/adaptive_navigation_shell_test.dart
git commit -m "feat(nav): add adaptive navigation shell with bottom bar on narrow widths"
```

---

### Task 3: Rail overflow More (wide screens)

**Files:**
- Modify: `frontend/lib/app/views/shell/responsive_scaffold.dart`
- Modify: `frontend/test/app/views/shell/adaptive_navigation_shell_test.dart` (add rail More test with 8 destinations)

- [ ] **Step 1: Write the failing test**

Add to `adaptive_navigation_shell_test.dart`:

```dart
testWidgets('wide width shows More on rail when destinations exceed rail primary limit', (tester) async {
  final many = List.generate(
    8,
    (i) => ResponsiveDestination(icon: Icons.circle, label: 'Item $i'),
  );
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      home: AdaptiveNavigationShell(
        destinations: many,
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        child: const SizedBox(),
      ),
    ),
  );

  expect(find.text('More'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/app/views/shell/adaptive_navigation_shell_test.dart -v --plain-name "wide width shows More on rail"`
Expected: FAIL — no More on rail

- [ ] **Step 3: Update ResponsiveScaffold**

Import `nav_overflow_split.dart`. Before building destinations:
- `split = NavOverflowSplit.split(destinations, selectedIndex, NavOverflowSplit.maxRailPrimary)`
- Build `NavigationRailDestination` for each `split.visible`
- If `split.overflow.isNotEmpty`, add trailing More destination (icon only in compact mode)
- More tap → `showMenu` anchored to rail or `PopupMenuButton`
- Update doc comment: rail is for wide layouts; narrow uses `AdaptiveNavigationShell`

- [ ] **Step 4: Run tests**

Run: `cd frontend && flutter test test/app/views/shell/adaptive_navigation_shell_test.dart -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/app/views/shell/responsive_scaffold.dart \
        frontend/test/app/views/shell/adaptive_navigation_shell_test.dart
git commit -m "feat(nav): add More overflow on wide NavigationRail"
```

---

### Task 4: Wire `StaffShell` to adaptive shell

**Files:**
- Modify: `frontend/lib/features/shell/staff_shell.dart:161-167`
- Modify: `frontend/test/features/shell/staff_shell_nav_test.dart:135-158`

- [ ] **Step 1: Write the failing test (update existing phone test)**

Replace `staff_shell_nav_test.dart` phone test:

```dart
testWidgets('phone width shows bottom NavigationBar with Workforce when perms present', (
  tester,
) async {
  tokenStorage.claims = const JwtClaims(
    sub: 'u1',
    tenantId: 't1',
    permissions: ['auth.session', 'contractors.read', 'jobs.read'],
    actorType: 'tenant_member',
    iat: 1,
    exp: 2,
  );

  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    GetMaterialApp(home: StaffShell(child: const SizedBox())),
  );
  await tester.pumpAndSettle();

  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.byType(NavigationRail), findsNothing);
  expect(find.text('Workforce'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/features/shell/staff_shell_nav_test.dart -v --plain-name "phone width"`
Expected: FAIL — still finds NavigationRail

- [ ] **Step 3: Update StaffShell**

```dart
import '../../app/views/shell/adaptive_navigation_shell.dart';

// Replace ResponsiveScaffold block:
return AdaptiveNavigationShell(
  destinations: destinations,
  selectedIndex: index,
  onDestinationSelected: StaffShellNav.navigateTo,
  child: body,
);
```

Remove stale comment "Always left-side nav".

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/features/shell/staff_shell_nav_test.dart -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/shell/staff_shell.dart \
        frontend/test/features/shell/staff_shell_nav_test.dart
git commit -m "fix(staff-shell): use bottom nav on narrow screens to prevent content overflow"
```

---

### Task 5: Fix stale responsive QA test

**Files:**
- Modify: `frontend/test/core/responsive/responsive_qa_test.dart:116-133`

The test `'ResponsiveScaffold hides rail below tablet bp (7.4)'` expects rail hidden at 800px, but `ResponsiveScaffold` is rail-only by design. Update test to assert rail **always shows** (it's the adaptive shell's job to pick bottom nav):

```dart
testWidgets('ResponsiveScaffold always shows rail (adaptive shell handles narrow)', (tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      home: ResponsiveScaffold(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        destinations: sampleDestinations,
        child: const Text('Content'),
      ),
    ),
  );

  expect(find.byType(NavigationRail), findsOneWidget);
  expect(find.text('Content'), findsOneWidget);
});
```

Add new test in same file for `AdaptiveNavigationShell` at 800px → bottom bar.

- [ ] Run: `cd frontend && flutter test test/core/responsive/responsive_qa_test.dart -v`
- [ ] Commit: `test: align responsive QA tests with adaptive navigation shell`

---

### Task 6: Migrate `ContractorShell` (required — eng review D2)

**Files:**
- Modify: `frontend/lib/features/shell/contractor_shell.dart:65-95`
- Test: add `frontend/test/features/shell/contractor_shell_nav_test.dart` (if missing)

Replace manual wide/narrow branch with `AdaptiveNavigationShell` (5 destinations — no More on bottom today, but future-proof).

- [ ] **Step 1: Write failing widget tests** — phone → NavigationBar, wide → NavigationRail

```dart
testWidgets('contractor phone width uses bottom NavigationBar', (tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    GetMaterialApp(home: ContractorShell(child: const SizedBox())),
  );
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.byType(NavigationRail), findsNothing);
});
```

- [ ] **Step 2: Run test** — expected FAIL (needs Get setup like staff tests)
- [ ] **Step 3: Replace LayoutBuilder branch with `AdaptiveNavigationShell`**
- [ ] **Step 4: Run tests** — expected PASS
- [ ] **Step 5: Commit** — `refactor(contractor-shell): reuse AdaptiveNavigationShell`

---

### Task 7: Manual verification + doc touch

**Files:**
- Modify: `frontend/docs/admin-feedback-task-breakdown.md` — add AD-3 row noting responsive nav reversal

- [ ] Run app at 390px width: staff home shows bottom bar, content full width, no yellow/black overflow stripes
- [ ] Run app at 1280px: left rail, all labels visible
- [ ] Tap More on phone (with full permissions → 6 items): sheet shows Payments + Settings
- [ ] Select overflow item: navigates, sheet closes, promoted item visible in bar
- [ ] Update admin-feedback doc AD-3: `[x] Responsive staff nav — bottom bar <1024px, left rail ≥1024px, More overflow`

---

## Test Plan & Verification

**Coverage target:** ≥90% line coverage on `nav_overflow_split.dart` and `adaptive_navigation_shell.dart`; every branch in `NavOverflowSplit.split` has a unit test; widget tests cover narrow/wide/More paths.

**Critical paths (must pass before ship):**
- Phone (390px) staff shell → bottom `NavigationBar`, no `NavigationRail`, body uses full width → `staff_shell_nav_test.dart` phone test
- Desktop (1280px) staff shell → left `NavigationRail` → `adaptive_navigation_shell_test.dart` wide test
- 6 destinations on phone → More visible, overflow sheet lists remaining items → `adaptive_navigation_shell_test.dart` More test
- Selecting Payments from More → navigates to payments route, **More button stays highlighted** → widget test + manual

**Edge cases & error paths:**
- 0 destinations (permissions loading) → existing `StaffShell` banner path unchanged → `staff_shell_nav_test.dart` fallback test
- 1–4 destinations → no More button → unit test `count <= maxVisible`
- Selected item in overflow → More button highlighted → `nav_overflow_split_test.dart` moreSelected test
- 8 destinations on desktop → rail More → widget test wide More test
- Rapid resize across 1024px → no exception → manual drag-resize on web

**Regression guards:**
- Permission-filtered destinations unchanged → existing `staff_shell_nav_test.dart` destination tests
- Contractor shell still works → `contractor_shell_nav_test.dart` (Task 6)
- `ResponsiveScaffold` at 1280px still renders rail → `responsive_qa_test.dart` 7.5 test

**Verification commands:**
- Unit: `cd frontend && flutter test test/app/views/shell/nav_overflow_split_test.dart -v` — expected: all pass
- Widget: `cd frontend && flutter test test/app/views/shell/adaptive_navigation_shell_test.dart test/features/shell/staff_shell_nav_test.dart -v` — expected: all pass
- Responsive QA: `cd frontend && flutter test test/core/responsive/responsive_qa_test.dart -v` — expected: all pass
- Full frontend: `cd frontend && flutter test` — expected: no regressions
- Manual: `cd frontend && flutter run -d chrome --web-browser-flag "--window-size=390,844"` then `--window-size=1280,900`

**Acceptance criteria (from spec):**
- [ ] Below breakpoint, menu at bottom with More for extra items → Task 2 + Task 4
- [ ] Above breakpoint, menu on left with More if needed → Task 3 + Task 4
- [ ] Same behavior for all users (no role-specific breakpoints) → no permission branching in layout code
- [ ] Page content no longer pushed off-screen on narrow widths → manual 390px verification

---

## NOT in scope

- Changing breakpoint values below/above 1024 (uses existing `Breakpoints.tablet`)
- Drawer-based navigation
- Animating rail ↔ bottom transitions
- Fixing unrelated `RenderFlex` overflows inside page content (e.g. roster cards)
- Backend or permission model changes
- ~~Contractor shell migration~~ — **in scope** per eng review D2

## What already exists

- `ContractorShell` narrow/wide pattern — **reuse** via `AdaptiveNavigationShell`
- `ResponsiveScaffold` left rail styling — **extend** for rail More
- `Breakpoints.tablet = 1024` — **reuse** as the single width threshold
- `StaffShellNav` destination list + permission filtering — **unchanged**
- Stale `responsive_qa_test.dart` expecting hidden rail — **fix** in Task 5

---

## Parallelization

Sequential implementation, no parallelization opportunity — all tasks touch `frontend/lib/app/views/shell/` and `staff_shell.dart` in dependency order.

| Step | Modules | Depends on |
|------|---------|------------|
| Task 1 | shell/nav_overflow_split | — |
| Task 2 | shell/adaptive_navigation_shell | Task 1 |
| Task 3 | shell/responsive_scaffold | Task 1 |
| Task 4 | features/shell/staff_shell | Task 2, 3 |
| Task 5 | tests | Task 4 |
| Task 6 | contractor_shell (optional) | Task 2 |

---

## Failure modes

| Failure | Test? | Handling | User sees |
|---------|-------|----------|-----------|
| More highlight wrong when overflow selected | Yes (unit) | `moreSelected` flag drives NavigationBar index | Wrong tab highlighted — prevented by moreSelected test |
| More sheet doesn't close after tap | Manual | `Navigator.pop` after navigate | Stuck sheet — verify in Task 7 |
| 1024px boundary flicker | Manual | `LayoutBuilder` instant switch | Brief layout jump — acceptable per YAGNI |
| Empty destinations during hydrate | Existing test | StaffShell banner | Banner message — unchanged |
| Rail More menu off-screen | Widget | Anchor to rail overlay | Menu clipped — use `showModalBottomSheet` on rail too if needed |

**Critical gap flagged:** None if all tests pass; primary risk is More highlight / index mapping bugs → covered by unit + widget tests.

---

## GSTACK REVIEW REPORT

**Review date:** 2026-08-20  
**Reviewer:** /gstack-plan-eng-review  
**Plan:** `frontend/docs/superpowers/plans/2026-08-20-admin-responsive-nav.md`  
**Status:** APPROVED WITH FOLDED DECISIONS

### Step 0 — Scope Challenge

- **Existing code:** `ContractorShell` already implements narrow bottom / wide rail at 1024px; `StaffShell` diverged (always rail) causing the reported overflow. Plan correctly reuses contractor pattern via shared shell.
- **Minimum change:** 2 new files + 4 modified + tests. Under 8-file smell threshold. No new services/classes beyond focused helpers.
- **Complexity:** 1 new orchestrator (`AdaptiveNavigationShell`) + 1 pure helper (`NavOverflowSplit`). Acceptable.
- **Search check [Layer 1]:** Flutter Material 3 `NavigationBar` / `NavigationRail` are built-ins; no custom nav framework needed.
- **Completeness:** Full test matrix included; Task 6 upgraded from optional to required per DRY preference.
- **Scope accepted as-is** after folding review decisions below.

### Decisions folded into plan

| ID | Decision | Choice |
|----|----------|--------|
| D1 | Rail vs bottom breakpoint | **1024px** (`Breakpoints.tablet`) |
| D2 | ContractorShell migration | **Include Task 6** in same PR |
| D3 | Overflow selection UX | **Highlight More** when selected item is in overflow (no slot promotion) |

### Review section summary

| Section | Issues found | Notes |
|---------|-------------|-------|
| Architecture | 0 unresolved | Shared shell + pure split is clean; reverses AD-1 intentionally |
| Code Quality | 0 unresolved | D3 changed promotion → More highlight (simpler, less bar churn) |
| Tests | 0 unresolved | Added contractor shell test requirement in Task 6 |
| Performance | 0 | UI-only, no concerns |

### NOT in scope (confirmed)

- Drawer navigation
- Per-role breakpoints
- Page-level overflow fixes (roster cards etc.)

### What already exists (confirmed)

- `ContractorShell` narrow/wide pattern → migrate to shared shell (Task 6)
- `Breakpoints.tablet = 1024` → reuse
- `ResponsiveScaffold` rail styling → extend for rail More

### Implementation Tasks (from review)

- [ ] **T1 (P1, human: ~1h / CC: ~10min)** — `NavOverflowSplit` — pure overflow split with More highlight
  - Surfaced by: Architecture — shared overflow logic
  - Files: `nav_overflow_split.dart`, `nav_overflow_split_test.dart`
  - Verify: `flutter test test/app/views/shell/nav_overflow_split_test.dart`
- [ ] **T2 (P1, human: ~2h / CC: ~15min)** — `AdaptiveNavigationShell` — bottom/rail width branch
  - Surfaced by: Architecture — staff shell overflow root cause
  - Files: `adaptive_navigation_shell.dart`, tests
  - Verify: `flutter test test/app/views/shell/adaptive_navigation_shell_test.dart`
- [ ] **T3 (P2, human: ~1h / CC: ~10min)** — `ResponsiveScaffold` — rail More overflow
  - Surfaced by: Spec — wide-screen More when needed
  - Files: `responsive_scaffold.dart`
  - Verify: adaptive shell wide More widget test
- [ ] **T4 (P1, human: ~30min / CC: ~5min)** — `StaffShell` — wire adaptive shell
  - Surfaced by: Bug report — RenderFlex overflow on phone
  - Files: `staff_shell.dart`, `staff_shell_nav_test.dart`
  - Verify: phone test expects NavigationBar
- [ ] **T5 (P2, human: ~30min / CC: ~5min)** — Tests — fix stale responsive QA test
  - Files: `responsive_qa_test.dart`
  - Verify: `flutter test test/core/responsive/responsive_qa_test.dart`
- [ ] **T6 (P2, human: ~1h / CC: ~10min)** — `ContractorShell` — DRY migration
  - Surfaced by: Code Quality — duplicated narrow/wide logic (eng review D2)
  - Files: `contractor_shell.dart`, new contractor nav test
  - Verify: contractor shell widget tests

### Completion summary

- Step 0: Scope accepted as-is (decisions folded)
- Architecture Review: 0 unresolved issues
- Code Quality Review: 0 unresolved (D3 applied)
- Test Review: diagram produced, 0 gaps after Task 6 test added
- Performance Review: 0 issues
- NOT in scope: written
- What already exists: written
- TODOS.md updates: 0 (admin-feedback AD-3 covered in Task 7)
- Failure modes: 0 critical gaps flagged
- Outside voice: skipped
- Parallelization: sequential, 6 tasks
- Lake Score: 3/3 complete options chosen (1024bp, include Task 6, highlight More)
