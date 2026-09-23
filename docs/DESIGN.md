# Rostiq — Design System

**Canonical product design source of truth.**  
Implementation must follow this document. Token code lives in Flutter; marketing surfaces should match the same roles even when the stack differs.

| Field | Value |
|-------|-------|
| **Product** | Rostiq |
| **Direction** | **B+** — Care Teal chrome + Coral CTAs |
| **Showcase** | [colors.rostiq.co/#b](https://colors.rostiq.co/#b) (B) + coral-as-CTA hybrid |
| **Production branch** | `ios` (frontend) |
| **Last updated** | 2026-09-23 |

---

## 1. Principles

1. **Inevitable care ops** — coordinators and workers should not think about chrome; colour encodes status and action.
2. **Two brand colours, scarce coral** — teal structures; coral acts. Never rainbow every chip.
3. **Thumb-first on phone** — primary jobs stay on the bottom bar; overflow goes under **More**, not a hamburger-only IA.
4. **One mark** — R + analog clock SVG, tinted at runtime. Do not invent a second logo style in-app.
5. **Tokens over hex** — UI uses `AppColors.*` / theme; no ad-hoc `Colors.grey` or raw status hexes in features.
6. **Light-only for now** — no dark `ColorScheme` until explicitly scoped.

---

## 2. Brand mark

| Asset | Path | Notes |
|-------|------|-------|
| Wordmark SVG | `frontend/assets/images/logo.svg` | Monochrome black source |
| Widget | `RostiqLogo` in `lib/shared/widgets/rostiq_logo.dart` | `flutter_svg` + `ColorFilter` / `BlendMode.srcIn` |
| Default tint | `AppColors.brand` (teal) | Login, gateway, chrome |
| Alternate tint | `AppColors.cta` (coral) | Rare; high-energy moments only |
| Launcher / store | `assets/branding/rostiq_icon_master_1024.png` | Raster — not SVG-tintable |

**Do not** bake teal/coral into the SVG file. **Do not** fall back to a generic Material icon when the asset loads successfully.

---

## 3. Colour

### Role contract

| Role | Colour | Use | Do not use for |
|------|--------|-----|----------------|
| **Chrome / brand** | Teal `#0F766E` | AppBar, selected nav, focus, links, soft fills | Primary buttons |
| **CTA** | Coral `#E76F51` | ElevatedButton, FAB, Assign / Add | Open-slot state, errors |
| **Open / needs worker** | Amber `#B45309` | Open roster slots | Errors or CTAs |
| **Error** | Red `#DC2626` | Validation, failures | Warnings that are not errors |
| **Success** | Green `#16A34A` | Positive confirmation | Neutral “active” chips |

### Token table (Flutter `AppColors`)

| Token | Hex | Usage |
|-------|-----|-------|
| `brand` / `primary` | `#0F766E` | AppBar, rail selection, focus, links |
| `brandDark` / `primaryDark` | `#0B5A54` | Pressed chrome, selected label |
| `brandSoft` / `primaryLight` | `#D5EFEB` | Hover, nav indicator wash |
| `cta` / `accent` | `#E76F51` | Primary actions |
| `ctaDark` / `accentDark` | `#CF5A3D` | CTA pressed |
| `accentSoft` / `incompleteBackground` | `#FCE8E2` | Incomplete / human-attention wash |
| `background` | `#F4F8F7` | Page canvas |
| `surface` / `cardBackground` | `#FFFFFF` | Cards, sheets, bottom nav |
| `divider` / `slate200` | `#D5E2DF` | Borders, inputs |
| `textDark` | `#14201E` | Body / titles |
| `textMuted` | `#5B6B68` | Captions, inactive nav |
| `onPrimary` / `onCta` / `textLight` | `#FFFFFF` | Text on teal or coral |
| `openSlot` | `#B45309` | Open slots |
| `openSlotBackground` | `#FFF7ED` | Open-slot wash |
| `error` / `errorBackground` | `#DC2626` / `#FEF2F2` | Errors |
| `success` / `successBackground` | `#16A34A` / `#F0FDF4` | Success |

### Theme wiring (`lib/main.dart`)

```
colorScheme.primary            → brand teal
colorScheme.secondary          → cta coral
appBarTheme                    → brand teal
elevatedButtonTheme            → cta coral
floatingActionButtonTheme      → cta coral
scaffoldBackgroundColor        → background mint
```

Explicit button fills in features should use `AppColors.cta`, not `AppColors.primary`.

### Compare board

`frontend/docs/color-decision-board.html` — all directions on key screens (Login, Clients, Today, Roster, Dashboard).

---

## 4. Typography

| Role | Current (ships) | Target (optional polish) |
|------|-----------------|--------------------------|
| App UI | Roboto via `ThemeData.fontFamily` | Plus Jakarta Sans (headings) + Inter (body) if we invest in fonts |
| Marketing | Heading + body CSS vars on landing | Align to same family when landing moves to B+ |

**App type scale (practical)**

| Style | Approx | Weight | Use |
|-------|--------|--------|-----|
| AppBar title | 17.sp | 700 | Screen title |
| Section title | `titleMedium` | 600–700 | Card / form sections |
| Body | 16.sp / `bodyLarge` | 400 | Primary copy |
| Caption / meta | 12–13 | 400 | Muted helper text |
| Button label | 14.sp | 600 | Elevated / outlined |

Prefer `Get.textTheme` / `Theme.of(context).textTheme` over one-off sizes when possible.

---

## 5. Shape, spacing, elevation

| Token | Value |
|-------|-------|
| Card radius | `16.r` (Material cards) |
| Button radius | `12.r` |
| Input radius | `12.r` |
| Sticky form CTA min height | `48` |
| Page list padding | `16` |
| Card border | `1` × `AppColors.divider` (prefer border over heavy shadow) |
| Card elevation | `0.5` |

Breakpoints (`lib/core/responsive/breakpoints.dart`):

| Name | Width |
|------|-------|
| Phone | `< 600` |
| Tablet shell switch | `≥ 1024` (`Breakpoints.tablet`) |
| Form max width | `480` |
| Max content | `1200` |

Always branch layout on `LayoutBuilder` width, not raw `MediaQuery`, for shell decisions.

---

## 6. Navigation

### Staff (phone)

Bottom bar — **4 primaries + More** (not a top-left burger as the sole map):

| Slot | Destination |
|------|-------------|
| 1 | Home |
| 2 | Roster |
| 3 | Clients |
| 4 | Workforce |
| 5 | **More** → sheet |

**More sheet** (order): Attendance review (when present), Payments, Billing, Settings. Compliance stays route-hidden until `showComplianceNav` is enabled.

Implementation: `StaffShellNav` + `AdaptiveNavigationShell` (`narrowPrimaryCount: 4`).

### Staff (tablet / desktop)

Full destination list on a **left NavigationRail** — no More tab.

### Contractor

Keep five bottom tabs: Home · Visits · Schedule · Credentials · Profile (≤5; no More required).

### Anti-patterns

- Crowding 6–8 labels into the phone bottom bar
- Hamburger as the only way to reach Roster / Clients
- Hiding primary daily work behind More

---

## 7. Components & states

| Pattern | Guidance |
|---------|----------|
| Primary button | Coral fill, white label |
| Secondary / outline | Border + text; teal text OK for links |
| FAB / extended FAB | Coral |
| Selected nav | Teal indicator (~18% brand alpha) |
| Open slot card | Amber wash + amber label; Assign CTA coral |
| Incomplete chip | Coral soft wash |
| Active / assigned chip | Brand soft wash |
| Error banner | Error background + error text |
| Empty state | Muted text; optional brand-tinted icon — no grey Material defaults |
| Loading | `CircularProgressIndicator` with theme primary (teal) |

---

## 8. Surfaces by product

| Surface | Stack | Must follow |
|---------|-------|-------------|
| Flutter app (iOS / Android / web) | `AppColors` + `ThemeData` | This doc §3–7 |
| Landing / register | Tailwind + `globals.css` | Same **roles** (teal chrome, coral CTA); today still charcoal — **gap** |
| colors.rostiq.co | Static showcase | Decision reference only |

When landing adopts B+, map CSS variables to the same hex roles as §3.

---

## 9. Source files

| Concern | Path |
|---------|------|
| Colour constants | `frontend/lib/app/themes/app_colors.dart` |
| Theme | `frontend/lib/main.dart` → `_appTheme()` |
| Logo widget | `frontend/lib/shared/widgets/rostiq_logo.dart` |
| Adaptive shell | `frontend/lib/app/views/shell/adaptive_navigation_shell.dart` |
| Staff destinations | `frontend/lib/features/shell/staff_shell.dart` |
| Contractor destinations | `frontend/lib/features/shell/contractor_shell.dart` |
| Colour decision HTML | `frontend/docs/color-decision-board.html` |
| Colour-only notes | `frontend/docs/color-identity.md` (points here) |

---

## 10. Change control

1. Propose token or IA changes in a short PR description against this file.
2. Update `AppColors` / shell / logo **and** this doc in the same change when roles shift.
3. Do not reintroduce charcoal-as-primary or burgundy landing tokens without an explicit product decision.
4. Prefer rebasing design work onto **`ios`**, not `master`.

---

*Rostiq design system — B+ Care Teal + Coral CTA.*
