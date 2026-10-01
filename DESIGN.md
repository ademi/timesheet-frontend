# Rostiq — Design system

Staff / contractor **app UI** (not marketing). Calm teal chrome, coral actions, dense but readable workspaces. Tokens live in `lib/app/themes/app_colors.dart` and `lib/main.dart` (`_appTheme`).

Source of truth for visual decisions on this branch (Travel / labour audit 2026-10-01). Deviations from this file are higher severity in `/design-review`.

---

## Product posture

| | |
|--|--|
| **Classifier** | APP UI — task-first, data-dense |
| **Brand** | Rostiq — care / NDIS operations |
| **Feel** | Workmanlike, calm, trustworthy |
| **Not** | Landing-page heroes, feature grids, mood copy, purple SaaS kits |

Users scan shift detail, roster, and wizards. Prefer utility language: orientation, status, action.

---

## Color

Use `AppColors` — do not invent one-off hex in feature widgets.

| Token | Hex | Role |
|-------|-----|------|
| `brand` / `primary` | `#0F766E` | AppBar, nav chrome, focus, selected state, OutlinedButton ink |
| `brandDark` | `#0B5A54` | Pressed / dark teal |
| `brandSoft` | `#D5EFEB` | Soft chrome wash, hover rows |
| `cta` / `accent` | `#E76F51` | ElevatedButton, FAB, primary sticky actions |
| `ctaDark` | `#CF5A3D` | CTA pressed |
| `accentSoft` | `#FCE8E2` | Incomplete / soft coral wash |
| `background` | `#F4F8F7` | Scaffold |
| `surface` | `#FFFFFF` | Cards, sheets |
| `textDark` | `#14201E` | Primary copy |
| `textMuted` | `#5B6B68` | Helpers, secondary labels |
| `textLight` | `#FFFFFF` | On brand / on CTA |
| `divider` | `#D5E2DF` | Borders, hairlines |
| `error` | `#DC2626` | Errors **and** soft warnings (same family) |
| `errorBackground` | `#FEF2F2` | Error / warning wash |
| `success` | `#16A34A` | Success text |
| `successBackground` | `#F0FDF4` | Success wash |
| `openSlot` | `#B45309` | Amber — open roster slots (not error) |
| `openSlotBackground` | `#FFF7ED` | Amber wash |

**Rules**

- Teal = chrome. Coral = decide / commit.
- Warnings and blocking errors both use `error` + `errorBackground` (light wash, red text). Do **not** invent loud dark-red banners or white-on-crimson chips.
- Status chips: soft background + matching foreground; `BorderRadius` ~12 for pills.
- No purple/indigo gradients. No decorative blob backgrounds.

---

## Typography

| | |
|--|--|
| **Family** | Roboto (see `ThemeData.fontFamily`) |
| **AppBar title** | 17, w700, on brand |
| **Section title** | `titleMedium` / `titleSmall` |
| **Body** | Default theme; helpers 13 muted |
| **Buttons** | 14, w600 |

**Rules**

- One job per section: one heading, short supporting line if needed.
- Helper copy ≤ one short sentence. If deleting 30% improves scan, delete.
- Never use placeholder-as-only-label; keep `InputDecoration.labelText` visible.
- Quantities show units (`min`, `km`) next to the number in lists and review rows.

**Known tension:** Roboto is utilitarian and can read generic. Acceptable for this app UI; do not swap to Inter/Poppins “AI default” stacks without an intentional brand pass.

---

## Layout & spacing

| Token / pattern | Value |
|-----------------|-------|
| Base rhythm | 4 / 8 / 16 |
| Form page padding | 16 |
| Sticky footer padding | 16 |
| Card radius | 16 |
| Button radius | 12 |
| Chip / pill radius | 12 |
| Form max width | `PageContentWidth.narrow` (~760) |
| Lists / boards | `workflow` (~960) or `wide` (~1200) |
| Design size (ScreenUtil) | 390 × 844; web fonts must not overscale |

**Rules**

- Shell chrome (AppBar, tab rail, FAB) full-bleed; wrap **content** in `PageContent`.
- Cards earn their keep — interactive or bordered list rows, not decorative mosaics.
- Multi-step wizards: step indicator (track + label) above `PageContent`; sticky actions below scroll.

---

## Components

### AppBar

Teal (`brand`), white icons/title, elevation 0. Back affordance always labeled with destination when leaving a wizard (`tooltip: 'Back to shift'`).

### Primary / secondary actions

| Kind | Widget | Color |
|------|--------|-------|
| Commit | `ElevatedButton` / sticky primary | `cta` |
| Secondary / back | `OutlinedButton` | brand border / ink |
| Destructive | Error-colored text or outlined `error` | confirm first |

Sticky form footers: `FormStickyActions`.

- Mid-wizard: **Cancel** (exit) or **Back** (previous step) — label must match behavior.
- Final review step: secondary = **Back** (previous step), primary = **Save** / commit. Never label “Cancel” if the action only goes back a step.

### Toasts

`AppToast` (`Get.snackbar`). **Pop the route before showing a success toast** — snackbar is a route; `Get.back` after toast dismisses the snackbar, not the page.

### Inline alerts

Default pattern (errors and soft warnings):

```dart
Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: AppColors.errorBackground,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(message, style: const TextStyle(color: AppColors.error)),
);
```

Optional title + body in the same wash (bold title, regular body). No warning icons required unless they clarify status globally.

### Forms

- `OutlineInputBorder` fields.
- Read-only values: `InputDecorator` + plain `Text`.
- Segmented claim/type controls: `SegmentedButton` when the user can choose; hide when editing locks the kind.
- Soft validation banners sit **next to the field they describe** (e.g. over-cap under Minutes).

### Lists (shift detail, etc.)

- Section title + optional `+ Add` in brand.
- Row: primary label, optional status chip, secondary line (split / notes), Edit / Delete.
- Split mode copy: **Equal split** / nominated name — not a bare “Equal”.

---

## Motion

Keep motion purposeful and short (≤ ~300ms). Prefer opacity/transform. Respect `prefers-reduced-motion` where custom animation is added. Step changes may be instant; no decorative page choreography.

---

## Content voice

- Active, specific: “Save travel”, “Back to shift”, “Over NDIS travel-time limit”.
- Soft NDIS caps: warn loudly enough to notice, never block save; say the user can still save.
- Claim-type language (“Provider Travel”) belongs in helpers, not as the support-item **name**. Snapshot codes use **hourly item** wording.
- Happy talk and long instructions die. Scan first.

---

## Accessibility

- Touch targets ≥ 44px (`minimumSize` on buttons).
- Don’t rely on hover-only affordances (staff use web + tablet).
- Semantic live regions for soft-cap banners when they appear.
- Flutter web: enable semantics (“Enable accessibility”) for automated audits; product UI must still be usable without that click.

---

## Anti-patterns (do not ship)

1. Dark crimson / white-text “alarm” banners for soft warnings.
2. `Get.snackbar` then `Get.back` (nav eaten by toast).
3. Review/footer **Cancel** that only returns to the previous step.
4. Support-item labels that rename hourly codes to “Provider Travel”.
5. Purple gradients, 3-column icon feature grids, emoji-as-UI, bubbly uniform radius everywhere.
6. Full-bleed body text without `PageContent` max width.
7. Cards that are only decoration.

---

## Travel / labour (feature notes)

| Surface | Expectation |
|---------|-------------|
| Shift detail Travel | Labour rows: `{n} min · Provider Travel` + Over-cap chip when soft-capped; km rows show code + km |
| Wizard Item | Worker travel time vs Vehicle kilometres; labour shows read-only hourly item + Minutes |
| Soft MMM cap | `errorBackground` banner under Minutes; save still allowed |
| Uniqueness | One unclaimed labour claim per shift — edit existing, don’t create a second |

---

## File map

| Concern | Location |
|---------|----------|
| Color tokens | `lib/app/themes/app_colors.dart` |
| Theme / type | `lib/main.dart` → `_appTheme` |
| Sticky actions | `lib/shared/widgets/form_sticky_actions.dart` |
| Toasts | `lib/shared/widgets/app_toast.dart` |
| Content width | `lib/core/responsive/page_content.dart` |

When you change a token here, update `AppColors` / theme in the same PR.
