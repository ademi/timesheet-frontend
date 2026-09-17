# Rostiq — Color Identity

Reference for the Flutter app palette (**B+ Care Teal + Coral CTA**).

Live tokens live in `lib/app/themes/app_colors.dart` and `ThemeData` in `lib/main.dart`.

---

## Direction

| Field | Value |
|-------|-------|
| **Direction** | **B+** — Care Teal chrome + Coral CTAs |
| **Showcase** | [colors.rostiq.co/#b](https://colors.rostiq.co/#b) with coral-as-CTA hybrid |
| **Mark** | Keep R + analog clock (`assets/images/logo.png` / branding master) |

Teal structures the workplace chrome. Coral is scarce and reserved for primary actions (buttons, FABs, Assign / Add). Open slots stay amber — not coral.

---

## Brand palette

### Chrome (teal)

| Token | Hex | Usage |
|-------|-----|-------|
| `brand` / `primary` | `#0F766E` | AppBar, rail/selection, focus rings, links, soft fills |
| `brandDark` / `primaryDark` | `#0B5A54` | Pressed chrome, selected label |
| `brandSoft` / `primaryLight` | `#D5EFEB` | Hover, nav indicator wash |

### CTA (coral)

| Token | Hex | Usage |
|-------|-----|-------|
| `cta` / `accent` | `#E76F51` | ElevatedButton, FAB, primary form actions |
| `ctaDark` / `accentDark` | `#CF5A3D` | CTA pressed |
| `accentSoft` / `incompleteBackground` | `#FCE8E2` | Incomplete / human-attention wash |

### Background & surface

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#F4F8F7` | Page canvas |
| `surface` / `cardBackground` | `#FFFFFF` | Cards, sheets, bottom nav |
| `divider` / `slate200` | `#D5E2DF` | Borders, inputs |

### Text

| Token | Hex | Usage |
|-------|-----|-------|
| `textDark` | `#14201E` | Body / titles |
| `textMuted` | `#5B6B68` | Captions, inactive nav |
| `onPrimary` / `onCta` / `textLight` | `#FFFFFF` | Text on teal or coral fills |

### Semantic

| Token | Hex | Usage |
|-------|-----|-------|
| `openSlot` | `#B45309` | Open roster slots |
| `openSlotBackground` | `#FFF7ED` | Open-slot wash |
| `error` | `#DC2626` | Errors |
| `errorBackground` | `#FEF2F2` | Error wash |
| `success` | `#16A34A` | Success |
| `successBackground` | `#F0FDF4` | Success wash |

---

## Role contract

1. **Teal** = structure (AppBar, selected nav, focus, informational chips).
2. **Coral** = action (primary buttons, FABs, Assign / Add client).
3. **Amber** = open / needs worker (not coral).
4. **Red / green** = error / success only.
5. **Logo** = existing R + clock mark; do not replace with a generic Material icon when the asset loads.

---

## Theme wiring

```dart
colorScheme.primary   // brand teal
colorScheme.secondary // cta coral
appBarTheme           // brand teal
elevatedButtonTheme   // cta coral
floatingActionButtonTheme // cta coral
```

---

## Decision board

Local compare HTML: `docs/color-decision-board.html` (filters + side-by-side).

---

*Updated 2026-09-17 — B+ Care Teal + Coral CTA.*
