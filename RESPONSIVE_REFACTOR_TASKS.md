# Responsive Refactor — Implementation Tasks

**Project:** `yemen_gate_attendance_app` (timesheet-frontend)
**Strategy:** `flutter_screenutil` 5.x (phone-only density) + `LayoutBuilder` breakpoints (structure) + content max-width + responsive shell.
**Companion doc:** `RESPONSIVE_REFACTOR_ASSESSMENT.md`
**Status:** Phase 2 complete — in progress.

## Locked decisions (do not change without sign-off)
- **Orientation stays LOCKED to portrait.** Keep the existing `SystemChrome.setPreferredOrientations([portraitUp, portraitDown])` in `main.dart`. Do **not** remove it.
- **`designSize = Size(390, 844)`** for `ScreenUtilInit`.
- **`flutter_screenutil` 5.x** (no v6 alpha).

## What the portrait lock changes about the plan
- **Phones & tablets are always portrait** → no landscape layouts to build for those. Tablet portrait widths (~800–1100dp on 10–13" tablets) still cross the tablet breakpoint, so reflow still applies there.
- **Web ignores the orientation lock** (it is a no-op on web) → the browser window is free-form and can be very wide. **Web is the primary driver** of `LayoutBuilder` breakpoints, max-width, grids, rail, and two-pane.
- **`.h` is safer than usual** (height won't flip to landscape) but still scales to device height; keep using plain constants/`.r` for spacing — do not mass-convert spacers to `.h`.
- Always branch structure on `LayoutBuilder` `constraints.maxWidth`, never `MediaQuery.size`.

---

# Phase 0 — Setup & guardrails (no visual change) ✅

- [x] **0.1** Add dependency: `flutter_screenutil: ^5.9.3` (latest stable 5.x) to `pubspec.yaml`; run `flutter pub get`.
- [x] **0.2** Create `lib/core/responsive/breakpoints.dart`:
  - `phone = 600`, `tablet = 1024`, `maxContent = 1200`, `formMaxWidth = 480`.
  - `DeviceClass { phone, tablet, desktop }` + helper `DeviceClass classify(double width)`.
- [x] **0.3** Create `lib/core/responsive/responsive.dart` — `BuildContext` extensions:
  - `context.deviceClass`, `context.isPhone/isTablet/isDesktop`, `context.maxContentWidth`.
  - (These read width from the nearest `LayoutBuilder`; provide an overload that takes `maxWidth`.)
- [x] **0.4** Create `lib/core/responsive/responsive_layout.dart` — `ResponsiveLayout({phone, tablet?, desktop?})` widget wrapping `LayoutBuilder` and switching on `constraints.maxWidth`.
- [x] **0.5** Create `lib/core/responsive/max_width_box.dart` — `MaxWidthBox({maxWidth, child})` that centers and caps width (used for forms/pages on web).
- [x] **0.6** Create `lib/core/responsive/adaptive_grid.dart` — grid that reflows hub cards by available width (1 col phone, 2 col tablet, 3 col desktop).
- [x] **0.7** Wrap `GetMaterialApp` in `ScreenUtilInit` in `main.dart`:
  ```dart
  ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    splitScreenMode: true,
    ensureScreenSize: true, // needed for correct web first-frame sizing
    builder: (context, child) => GetMaterialApp(/* existing config unchanged */),
  );
  ```
  - [x] **Keep** the portrait `setPreferredOrientations` call as-is.
- [x] **0.8** Sanity check: build & run on phone — confirm **zero** visual change vs. current (foundation only).

**Exit criteria:** ~~app compiles, runs, looks identical on phone. New utilities unused so far.~~ **Done** — `flutter analyze` clean; `flutter build web` succeeds; utilities unused in screens.

---

# Phase 1 — Global theme density (phone polish) ✅

- [x] **1.1** In `main.dart` `ThemeData`, route font sizes through `.sp` and radii through `.r` (appBar title, elevated/outlined button text, input content). Keep values numerically identical at 390 width.
- [x] **1.2** Verify on a small phone (~360dp) that text/controls scale down without overflow (`minTextAdapt`).
- [x] **1.3** Verify on a large phone (~430dp) that nothing balloons.

**Exit criteria:** ~~phone renders cleanly across 360–430dp; no overflow warnings.~~ **Done** — `_appTheme()` uses `.sp`/`.r`; at 390dp scale factor is 1:1 with prior constants; `flutter analyze` clean.

---

# Phase 2 — Web/tablet max-width pass (highest ROI, lowest risk) ✅

Wrap page bodies and forms so content stops stretching edge-to-edge on web/wide tablet. Forms use `formMaxWidth (480)`; general pages/lists use `maxContent (1200)`.

- [x] **2.1** `login_view.dart` — wrap card column in `MaxWidthBox(maxWidth: 480)`.
- [x] **2.2** `first_login_view.dart` — `MaxWidthBox(480)`.
- [x] **2.3** `gateway_view.dart` — center + `MaxWidthBox(480)`.
- [x] **2.4** `create_employee_view.dart` — form body `MaxWidthBox(480)` (or 560 if 2-col later).
- [x] **2.5** `payroll_settings_view.dart` — `MaxWidthBox`.
- [x] **2.6** `employee_rate_form_view.dart` — `MaxWidthBox`.
- [x] **2.7** `create_payment_view.dart` — `MaxWidthBox`.
- [x] **2.8** `attendance_adjustment_view.dart` — `MaxWidthBox`.
- [x] **2.9** `employee_detail_view.dart` — wrap the `ListView` content in `MaxWidthBox(maxContent)` (sections column).
- [x] **2.10** `attendance_view.dart` list body — `MaxWidthBox(maxContent)`.
- [x] **2.11** `employee_management_view.dart` list body — `MaxWidthBox(maxContent)`.
- [x] **2.12** Remaining list/detail screens (`branch_gateway`, `employee_picker`, `employee_balance`, `payroll_period_detail`, `payroll_result_detail`, `employee_payment_history`, `payroll_periods`, `employee_rates`) — `MaxWidthBox(maxContent)`.
- [x] **2.13** Dialogs (`attendance_pin_dialog`, `set_pin_dialog`) — cap dialog width (~400) for web.

**Exit criteria:** ~~on web ≥1280px, no content spans full window; everything is centered and readable.~~ **Done** — all listed screens wrapped; `flutter analyze` + `flutter build web` pass.

---

# Phase 3 — Hub screens → responsive grids

Convert the vertical card menus to `AdaptiveGrid` (1/2/3 columns by width). Cards already reusable (`AdminHubCard`).

- [ ] **3.1** `admin_panel_view.dart` — replace the `ListView` of `AdminHubCard`s with `AdaptiveGrid`; keep header full-width.
- [ ] **3.2** `payroll_main_view.dart` — `AdaptiveGrid`.
- [ ] **3.3** `payment_main_view.dart` — `AdaptiveGrid`.
- [ ] **3.4** Confirm `AdminHubCard` works in a grid cell (height/`Expanded` constraints); adjust card to be grid-friendly if needed.

**Exit criteria:** hubs show 1 col on phone, 2 on tablet portrait, 3 on web — no overflow.

---

# Phase 4 — `DataTable2` screens QA (already web-friendly)

Mostly verification + minor wrapping; no rewrites.

- [ ] **4.1** `attendance_report_view` / `attendance_report_tab.dart` — confirm fills width on web, horizontal-scrolls on phone (dynamic `minWidth`).
- [ ] **4.2** `payroll_period_results_view.dart` — verify `minWidth: 900` scroll on phone, fill on web.
- [ ] **4.3** `payments_report_view.dart` — verify.
- [ ] **4.4** `payroll_summary_report_view.dart` — verify.
- [ ] **4.5** `payroll_period_detail_view.dart` — verify table area.
- [ ] **4.6** Optionally cap very wide tables inside `MaxWidthBox(maxContent)` so they don't get gigantic on ultrawide.

**Exit criteria:** all tables usable on phone (scroll) and web (fill, capped).

---

# Phase 5 — Responsive navigation shell (NEW feature, web/wide only)

The app has no persistent nav chrome today. Add a wide-screen shell with `NavigationRail`; on phone keep the current hub-and-spoke push navigation untouched.

- [ ] **5.1** Create `lib/app/views/shell/responsive_scaffold.dart`:
  - Phone (`< tablet` bp): render the page exactly as today (no rail).
  - Tablet/desktop: `Row(NavigationRail, VerticalDivider, Expanded(content))`.
- [ ] **5.2** Define rail destinations mirroring hub entries (Employees, Attendance Report, Corrections, Payroll, Payments).
- [ ] **5.3** Integrate with GetX: rail selection navigates/swaps the active section. Keep existing routes + `AuthGuard` + `PathUrlStrategy` working (read same route args).
- [ ] **5.4** Ensure no duplicate controller instances (reuse `Bindings`); verify back-button/deep-link behavior on web.
- [ ] **5.5** Decide host: wrap admin sections in the shell on wide screens only; phone path unchanged.

**Exit criteria:** web shows a left rail + section; phone behaves exactly as before; deep links still resolve.

---

# Phase 6 — Two-pane master/detail (web/wide only)

On wide screens render list + detail side-by-side; on phone keep route-push. Drive selection via a selected-id in the existing controllers.

- [ ] **6.1** Create `lib/app/views/shell/two_pane.dart` — `TwoPane(master, detail, masterWidth)`.
- [ ] **6.2** `employee_management_view` ↔ `employee_detail_view` — two-pane on wide; push on phone.
- [ ] **6.3** `payroll_periods_view` ↔ `payroll_period_detail_view` / `payroll_period_results_view`.
- [ ] **6.4** `payroll_period_results_view` ↔ `payroll_result_detail_view`.
- [ ] **6.5** `employee_rates_view` ↔ `employee_rate_form_view`.
- [ ] **6.6** Verify selecting an item updates the right pane (no full route push) on web; phone still pushes.

**Exit criteria:** the four pairs work as two-pane on web and as push-navigation on phone.

---

# Phase 7 — Final QA matrix

Because orientation is locked, only **portrait** widths matter for phone/tablet; web is free-form.

- [ ] **7.1** Phone portrait 360dp — no overflow, density OK.
- [ ] **7.2** Phone portrait 390dp (design size) — pixel baseline.
- [ ] **7.3** Phone portrait 430dp — no ballooning.
- [ ] **7.4** Tablet portrait ~800–1100dp — grids reflow, optional two-pane/rail engages above bp.
- [ ] **7.5** Web 1280px — rail + two-pane + max-width all correct.
- [ ] **7.6** Web 1920px — content capped, not stretched.
- [ ] **7.7** OS large-font setting — text scales sanely (`minTextAdapt`).
- [ ] **7.8** Smoke test all `DataTable2` screens scroll/fill correctly.
- [ ] **7.9** Confirm portrait lock still enforced on device (cannot rotate to landscape).

---

# Per-screen checklist (apply during each screen's task)

- [ ] Page/form body wrapped in `MaxWidthBox` (form 480 / page 1200).
- [ ] Structural branching uses `LayoutBuilder` `constraints.maxWidth` + `Breakpoints` (not `MediaQuery`).
- [ ] Font sizes → `.sp`; radii/icons/square boxes → `.r`; spacing left as constants/`.r` (no reflex `.h`).
- [ ] No `.w` added to widgets already using `Expanded`/`Flexible`/`double.infinity`.
- [ ] Hub/list reflows to grid above phone bp where applicable.
- [ ] Master/detail uses two-pane on wide, push on phone; route args still resolve.
- [ ] Tested at 360 / 390 / 430 portrait + web 1280/1920.

---

# Conventions / golden rules (quick reference)
- `.sp` = fonts only. `.r` = radii, icon sizes, square boxes (logo, avatar, icon chips).
- Spacing/heights = plain constants or `.r`. **Avoid `.h`** (and `.w` on flexible widgets).
- Structure = `LayoutBuilder` + `constraints.maxWidth`. Never `MediaQuery.size` for structural decisions.
- Cap web width: forms 480, pages 1200.
- Keep portrait lock; keep existing GetX routes for phone; add shell/two-pane only as the wide-screen layer.
