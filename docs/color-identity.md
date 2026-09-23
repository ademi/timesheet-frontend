# Rostiq — Color Identity

> **Superseded as the full design source of truth.**  
> Read **[DESIGN.md](./DESIGN.md)** for colour, logo, navigation, type, and component rules.
>
> This file keeps a short palette cheat-sheet for quick lookup. If anything conflicts with `DESIGN.md`, **DESIGN.md wins**.

---

## Direction

**B+** — Care Teal chrome (`#0F766E`) + Coral CTAs (`#E76F51`).  
Showcase: [colors.rostiq.co/#b](https://colors.rostiq.co/#b).

Live code: `lib/app/themes/app_colors.dart`, `ThemeData` in `lib/main.dart`.

---

## Quick tokens

| Role | Token | Hex |
|------|-------|-----|
| Chrome | `brand` / `primary` | `#0F766E` |
| Chrome pressed | `brandDark` | `#0B5A54` |
| CTA | `cta` / `accent` | `#E76F51` |
| Page | `background` | `#F4F8F7` |
| Surface | `surface` | `#FFFFFF` |
| Text | `textDark` | `#14201E` |
| Muted | `textMuted` | `#5B6B68` |
| Border | `divider` | `#D5E2DF` |
| Open slot | `openSlot` | `#B45309` |

**Roles:** teal = structure · coral = action · amber = open slot · red/green = error/success.

**Logo:** `assets/images/logo.svg` via `RostiqLogo` (runtime tint; default teal).

**Compare board:** [color-decision-board.html](./color-decision-board.html).

---

*Pointer updated 2026-09-23 — see DESIGN.md.*
