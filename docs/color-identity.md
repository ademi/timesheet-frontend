# Rostiq — Color Identity

Reference for applying the landing page brand to the Flutter mobile app.

---

## Platform

| Field | Value |
|-------|-------|
| **Platform name** | **Rostiq** |
| **Tagline** | GPS Attendance & Payroll for Australian Teams |
| **Description** | Workforce management platform for Australian shift-based businesses — GPS attendance, smart payroll, and payment tracking. |
| **Package / repo** | `rostiq` |

---

## Brand palette

Deep burgundy primary, warm gold accent, and soft cream backgrounds. This is a **new brand** — not the Yemen Gate / Bab Al Yemen brown/cream mobile theme.

### Primary (burgundy)

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#7A1F1F` | Buttons, logo badge, links, icons, focus rings |
| `primary-dark` | `#4A0F0F` | Primary button hover, shadow tint |
| `primary-light` | `#B33A3A` | Headline gradient end, lighter brand accents |

### Accent

| Token | Hex | Usage |
|-------|-----|-------|
| `accent` | `#D4A017` | Secondary CTA, success icons, staff/kiosk portal |
| `accent-dark` | `#B38A13` | Secondary button hover |
| `accent-alt` | `#E76F51` | Warm coral highlight (defined in theme, use sparingly) |

### Background & surface

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#FFFDFB` | Page background (warm off-white) |
| `surface` | `#F9F2EF` | Section backgrounds, cards, form areas |

### Text

| Token | Hex | Usage |
|-------|-----|-------|
| `text` | `#1E1717` | Body copy (CSS variable) |
| `text-muted` / `muted` | `#7A6A6A` | Subtitles, captions, nav links |
| `slate-900` | `#0F172A` | Headings (Tailwind) |
| `slate-800` | `#1E293B` | Emphasized inline text |
| `slate-700` | `#334155` | Form labels, list items |
| `white` | `#FFFFFF` | Text on primary buttons, footer headings |

### UI neutrals (Tailwind Slate)

Used for borders, inputs, footer, and device mockups.

| Token | Hex | Usage |
|-------|-----|-------|
| `slate-100` | `#F1F5F9` | Borders, dividers |
| `slate-200` | `#E2E8F0` | Card borders, input borders |
| `slate-300` | `#CBD5E1` | Checkbox borders |
| `slate-400` | `#94A3B8` | Footer body text, placeholders |
| `slate-500` | `#64748B` | Footer copyright |
| `slate-600` | `#475569` | Mobile menu icon |
| `slate-700` | `#334155` | Mockup UI elements |
| `slate-800` | `#1E293B` | Mockup borders |
| `slate-900` | `#0F172A` | Footer background, mockup screens |

### Semantic / feedback

| Token | Hex | Usage |
|-------|-----|-------|
| `red-500` | `#EF4444` | Required field asterisk, delete icon |
| `red-600` | `#DC2626` | Validation errors |
| `red-50` | `#FEF2F2` | Error alert background |
| `red-700` | `#B91C1C` | Error alert text |

### Opacity overlays

Common patterns on the landing page (apply in Flutter with `withOpacity` or `Color.fromRGBO`):

| Pattern | Base | Opacity | Usage |
|---------|------|---------|-------|
| `primary/5` | `#7A1F1F` | 5% | Hero gradient, geofence info box |
| `primary/10` | `#7A1F1F` | 10% | Badges, icon backgrounds, blur orbs |
| `primary/20` | `#7A1F1F` | 20% | Input focus ring |
| `accent/5` | `#D4A017` | 5% | Hero gradient |
| `accent/10` | `#D4A017` | 10% | Staff portal icon background |

---

## Typography

| Role | Font | Flutter equivalent |
|------|------|------------------|
| **Headings** | Plus Jakarta Sans | `GoogleFonts.plusJakartaSans()` |
| **Body** | Inter | `GoogleFonts.inter()` |

---

## Shape & elevation

| Token | Value |
|-------|-------|
| Card radius | `12px` |
| Button radius | `8px` |
| Card shadow | `0 1px 3px rgba(74, 15, 15, 0.12), 0 1px 2px rgba(74, 15, 15, 0.08)` |
| Card hover shadow | `0 10px 25px rgba(74, 15, 15, 0.12)` |

---

## Gradients

| Name | Definition | Usage |
|------|------------|-------|
| **Text gradient** | `primary` → `primary-light` (`#7A1F1F` → `#B33A3A`) | Hero headline highlight |
| **Hero background** | `primary/5` → `background` → `accent/5` | Top section wash |
| **Portal staff** | `accent/5` → `accent/10` | Kiosk portal card |
| **Portal admin** | `primary/5` → `primary/10` | Admin portal card |

---

## Button variants

| Variant | Background | Text | Hover |
|---------|------------|------|-------|
| Primary | `#7A1F1F` | `#FFFFFF` | `#4A0F0F` |
| Secondary | `#D4A017` | `#FFFFFF` | `#B38A13` |
| Outline | transparent | `#7A1F1F` | `#7A1F1F` at 5% fill |
| Ghost | transparent | `#7A6A6A` | `#0F172A` on `#F9F2EF` |
| Inverse | `#FFFFFF` | `#7A1F1F` | `#F8FAFC` |

---

## Flutter color constants

Copy into `lib/theme/app_colors.dart` (or similar):

```dart
import 'package:flutter/material.dart';

/// Rostiq brand colors — sourced from landing page (globals.css + tailwind.config.ts)
abstract final class AppColors {
  // Primary
  static const Color primary = Color(0xFF7A1F1F);
  static const Color primaryDark = Color(0xFF4A0F0F);
  static const Color primaryLight = Color(0xFFB33A3A);

  // Accent
  static const Color accent = Color(0xFFD4A017);
  static const Color accentDark = Color(0xFFB38A13);
  static const Color accentAlt = Color(0xFFE76F51);

  // Background & surface
  static const Color background = Color(0xFFFFFDFB);
  static const Color surface = Color(0xFFF9F2EF);

  // Text
  static const Color text = Color(0xFF1E1717);
  static const Color textMuted = Color(0xFF7A6A6A);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);

  // Semantic
  static const Color error = Color(0xFFDC2626);
  static const Color errorBackground = Color(0xFFFEF2F2);
}
```

### Suggested `ThemeData` seed

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.primaryLight,
    secondary: AppColors.accent,
    onSecondary: AppColors.white,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.error,
  ),
  scaffoldBackgroundColor: AppColors.background,
);
```

---

## Source files

| File | Contents |
|------|----------|
| `app/globals.css` | CSS custom properties (`:root`) |
| `tailwind.config.ts` | Tailwind theme extension |
| `components/ui/Button.tsx` | Button variant colors |
| `app/layout.tsx` | Platform name and fonts |

---

*Generated from the Rostiq landing page codebase.*
