# Responsive Refactor — Manual Testing Guide

**Project:** `rostiq` (timesheet-frontend)  
**Companion docs:** `RESPONSIVE_REFACTOR_TASKS.md`, `RESPONSIVE_REFACTOR_ASSESSMENT.md`

This document describes **how to manually verify** each implementation phase. Automated coverage lives in `test/core/responsive/responsive_qa_test.dart`; use this guide for visual QA on real devices and browsers.

---

## Before you start

### Build & run

```bash
flutter pub get
flutter run                    # phone / emulator
flutter run -d chrome          # web
flutter build web              # optional production build check
```

### Test widths (portrait on phone/tablet; free-form on web)

| Label | Width | How to simulate |
|-------|-------|-----------------|
| Small phone | 360dp | Android emulator (e.g. Pixel 4a) or Chrome DevTools device preset |
| Design baseline | 390dp | iPhone 14 / Pixel 7 preset |
| Large phone | 430dp | iPhone 14 Pro Max preset |
| Tablet portrait | 800–1100dp | iPad / 10" tablet emulator, portrait only |
| Desktop web | 1280px | Chrome window or DevTools responsive mode |
| Ultrawide web | 1920px+ | Full HD monitor or DevTools width 1920 |

### Breakpoints to remember

- **Phone:** &lt; 600px  
- **Tablet:** 600–1023px (grids may show 2 columns)  
- **Rail + two-pane:** ≥ 1024px  
- **Max content width:** 1200px (pages/lists/tables)  
- **Form max width:** 480px  

### General pass criteria (every phase)

- No red/yellow overflow stripes in debug mode  
- No clipped text without ellipsis where expected  
- Tappable targets remain easy to hit (buttons, list rows, rail icons)  
- Back navigation and deep links still work after layout changes  

---

## Phase 0 — Setup & guardrails

**Goal:** Foundation compiles and runs; **no visible change** on phone vs. pre-refactor.

### Steps

1. Run the app on a **390dp phone** (or your daily driver).
2. Walk through: Gateway → Login → Home/Admin hub (whatever you can access without full backend).
3. Compare mentally (or against a pre-refactor build if you have one): spacing, font sizes, and card sizes should look **the same**.
4. Open Chrome DevTools → Console: confirm no `ScreenUtil` / layout exceptions on first paint.
5. Optionally inspect `lib/main.dart`: confirm `ScreenUtilInit` wraps `GetMaterialApp` with `designSize: Size(390, 844)` and portrait lock is **still present**.

### Pass if

- App launches on phone and web without errors.  
- Phone UI looks unchanged (foundation-only phase).  
- `flutter analyze` reports no new errors.

---

## Phase 1 — Global theme density

**Goal:** Text and control density scales sensibly on small and large phones via `.sp` / `.r` in theme.

### Steps

1. **360dp phone** — open Login, Gateway, and one admin list (e.g. Employees).
   - Read app bar titles, button labels, and input text: nothing should overflow or wrap awkwardly.
   - Text should be **slightly smaller** than on 390dp, not tiny or huge.
2. **390dp phone** — same screens; this is the design baseline (should match pre-refactor feel).
3. **430dp phone** — same screens; text/controls should **not balloon** (no comically large buttons or titles).
4. Toggle **system large text** (Android: Settings → Display → Font size; iOS: Larger Text):
   - Re-open Login and a form screen.
   - Layout should remain usable; `minTextAdapt` should prevent catastrophic overflow.

### Pass if

- 360dp: readable, no overflow warnings.  
- 430dp: proportional, not oversized.  
- Large system font: still usable (may scroll more — that is OK).

---

## Phase 2 — Max-width pass

**Goal:** On wide screens, content is **centered and capped** — not edge-to-edge.

### Form screens (max ~480px)

Test each at **1280px** and **1920px** web width:

| Screen | Route / how to open |
|--------|---------------------|
| Login | `/login` |
| First login | `/first-login` |
| Gateway | `/` |
| Create employee | Admin → Create employee |
| Payroll settings | Payroll hub → Settings |
| Employee rate form | Rates → Add/Edit (phone: full page; wide: right pane — see Phase 6) |
| Create payment | Payments → Create |
| Attendance adjustment | Corrections → Adjustment |

**For each:** content column should sit in the **center** of the window with empty margin on left/right. Form fields should not stretch to full browser width.

### List/detail screens (max ~1200px)

Test at **1920px** web width:

| Screen | What to check |
|--------|----------------|
| Employee management | List column capped, centered |
| Employee detail | Section cards capped |
| Attendance (home) | List body capped |
| Branch gateway, employee picker, employee balance | Centered column |
| Payroll periods, period detail, period results, result detail | Centered |
| Employee rates, payment history | Centered |

**For each:** content block should stop growing around **1200px**; extra width shows background/margin, not stretched cards.

### Dialogs (~400px)

1. On web ≥1280px, trigger **Attendance PIN** and **Set PIN** dialogs.
2. Dialog width should stay **narrow and centered**, not full viewport.

### Pass if

- Forms ≤ ~480px wide on ultrawide.  
- Pages/lists ≤ ~1200px wide on ultrawide.  
- Dialogs stay compact on web.

---

## Phase 3 — Hub responsive grids

**Goal:** Admin, Payroll, and Payment hub menus reflow: **1 / 2 / 3 columns** by width.

### Screens

- Admin panel (`AdminPanelView`)
- Payroll main (`PayrollMainView`)
- Payment main (`PaymentMainView`)

### Steps

1. **360dp phone** — open each hub.
   - Cards stack in **one column**, full width of content area.
   - Titles/subtitles truncate with ellipsis if long (no overflow).
2. **800dp tablet portrait** — open each hub.
   - Cards should show **two columns** (or reflow cleanly between 1–2).
3. **1280px web** — open each hub.
   - Cards should show **three columns** where space allows.
   - Header/title area remains full width above the grid.
4. Tap several hub cards: navigation still works.

### Pass if

- Column count matches width (1 → 2 → 3).  
- `AdminHubCard` heights align in a row; no overflow in card text.

---

## Phase 4 — DataTable2 screens

**Goal:** Tables scroll horizontally on phone; fill available (capped) width on web.

### Screens

| Screen | Path hint |
|--------|-----------|
| Attendance report | Admin → Attendance Report |
| Payroll period results | Payroll → Period → Results |
| Payments report | Payments → Report |
| Payroll summary report | Payroll → Summary report |
| Payroll period detail | Payroll → Period detail (action cards, no table — verify layout only) |

### Steps — phone (360–430dp)

1. Open each table screen with **sample data** (or seed/mock if available).
2. Swipe **horizontally** on the table: all columns reachable via scroll.
3. Confirm no vertical overflow from fixed table height (page scrolls as a whole if needed).

### Steps — web (1280px and 1920px)

1. Open the same screens.
2. Table should **use the content area** up to the 1200px cap (not tiny in the corner, not full ultrawide).
3. At 1920px, table does **not** stretch beyond the max-width container.

### Pass if

- Phone: horizontal scroll works; headers and rows readable.  
- Web: table fills capped area; ultrawide shows side margins.

---

## Phase 5 — Responsive navigation shell

**Goal:** **Navigation rail** on wide screens only; phone unchanged (hub-and-spoke, no rail).

### Rail destinations (left side, ≥1024px)

1. Employees  
2. Report (Attendance Report)  
3. Corrections  
4. Payroll  
5. Payments  

### Steps — web ≥1280px

1. Log in and navigate to any admin route (e.g. `/admin`).
2. Confirm **left NavigationRail** is visible with 5 icons/labels.
3. Click each rail item:
   - Main section changes (Employees hub, Report, Corrections, Payroll hub, Payments hub).
   - URL updates (PathUrlStrategy); refresh browser — same section loads.
4. From Employees rail, drill into a sub-route (e.g. employee list, create employee):
   - Rail **stays visible**; content updates in the right pane.
5. Browser **back** button: returns to previous route without duplicate shells or blank panes.

### Steps — phone (&lt;1024px)

1. Same flows on 390dp phone.
2. Confirm **no rail** — full-screen pages only.
3. Hub cards → `Get.toNamed` push navigation with back button — same as before refactor.

### Steps — controller / auth

1. Switch rail sections several times: no duplicate loading spinners stuck forever.
2. Log out / session expiry (if testable): `AuthGuard` still blocks protected routes.

### Pass if

- Rail only at ≥1024px.  
- Phone behavior unchanged.  
- Deep links and back navigation work on web.

---

## Phase 6 — Two-pane master/detail

**Goal:** On wide screens, **list left + detail right**; on phone, **push** to detail route.

### Pairs to test

| Master | Detail | How to open |
|--------|--------|-------------|
| Employee management | Employee detail | Admin → Employees → tap employee |
| Payroll periods | Period detail | Payroll → Periods → tap period |
| Payroll period results | Result detail | Period → Results → tap row |
| Employee rates | Rate form | Payroll → Employee rates → tap rate / add |

### Steps — web ≥1280px

For **each pair**:

1. Open the master list in the left area.
2. Tap/select an item.
3. **Detail appears on the right** without a full-page route transition (no flash of empty scaffold).
4. Select a **different** item: right pane updates.
5. Resize window to **&lt;1024px**: layout should switch to **single column** (master only or stacked — phone mode); detail opens via navigation push when tapping.

### Steps — phone (&lt;1024px)

For **each pair**:

1. Tap an item in the list.
2. App **pushes** a new full screen (detail/form).
3. System/back button returns to list.
4. Route arguments still resolve (correct employee, period, rate).

### Pass if

- Wide: side-by-side, selection updates detail in place.  
- Phone: push navigation unchanged.  
- No “controller not found” errors when switching items quickly.

---

## Phase 7 — Final QA matrix

Run this checklist after Phases 0–6 pass individually. It is the **sign-off matrix** for the full refactor.

### 7.1 — Phone 360dp portrait

- [ ] Gateway, Login, one hub, one list, one form: no overflow  
- [ ] Density acceptable (Phase 1)  

### 7.2 — Phone 390dp portrait (design size)

- [ ] Baseline look matches expectations  
- [ ] App bar, buttons, inputs aligned and consistent  

### 7.3 — Phone 430dp portrait

- [ ] No ballooning text or oversized chrome  

### 7.4 — Tablet ~800–1100dp portrait

- [ ] Hub grids show 2 columns (Phase 3)  
- [ ] Below 1024px: **no rail**, **no two-pane** (single column + push)  
- [ ] At ≥1024px on a wide tablet window: rail/two-pane if applicable  

### 7.5 — Web 1280px

- [ ] Rail visible on admin routes (Phase 5)  
- [ ] Two-pane on the four master/detail pairs (Phase 6)  
- [ ] Max-width caps correct (Phase 2)  
- [ ] Hub 3-column grid (Phase 3)  

### 7.6 — Web 1920px

- [ ] Content still capped at ~1200px (pages) / ~480px (forms)  
- [ ] No stretched cards or full-bleed forms  

### 7.7 — OS large font

- [ ] Enable system large text on phone  
- [ ] Login + one data-heavy screen remain usable  

### 7.8 — DataTable2 smoke test

- [ ] All four table screens from Phase 4 checked in one session  
- [ ] Phone scroll + web fill verified  

### 7.9 — Portrait lock (device only)

1. On a **physical phone or tablet**, open the app.
2. Rotate device to landscape.
3. **Expected:** app stays in **portrait** (orientation does not follow device).

> Web ignores orientation lock — test 7.9 only on mobile builds.

### Phase 7 sign-off

- [ ] All items 7.1–7.9 checked  
- [ ] `flutter test` passes (including `test/core/responsive/responsive_qa_test.dart`)  
- [ ] `flutter analyze` — no new errors  
- [ ] `flutter build web` succeeds  

---

## Quick regression routes (smoke path)

Use this **15-minute path** after any responsive change:

1. Gateway → Login (forms, 480 cap)  
2. Admin panel (grid + rail at 1280px)  
3. Employees list → select employee (two-pane on web)  
4. Attendance Report (table)  
5. Payroll hub → Periods → Results (table + two-pane)  
6. Payments → Report (table)  
7. Resize browser 1280 → 800 → 360 (or switch device): rail and two-pane disappear appropriately  

---

## Recording issues

When filing a bug, include:

- Phase number (e.g. Phase 6)  
- Screen name and route URL  
- Viewport width (px) and platform (Chrome / Android / iOS)  
- Screenshot or screen recording  
- Steps to reproduce  
- Expected vs actual behavior  

---

## Related automated tests

```bash
# Responsive QA only
flutter test test/core/responsive/responsive_qa_test.dart

# Full suite
flutter test
```

Automated tests cover breakpoints, `MaxWidthBox`, rail visibility, `TwoPane`, grids, and portrait-lock **in code**. They do **not** replace visual QA on real devices for Phases 1–4 and 7.9.
