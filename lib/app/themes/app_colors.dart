import 'package:flutter/material.dart';

/// B+ Care Teal + Coral CTA — teal chrome, coral actions.
///
/// Tokens aligned with colors.rostiq.co Direction B, with coral as the
/// primary button/FAB fill (decision-board hybrid B+).
class AppColors {
  AppColors._();

  // Brand chrome (teal rail / AppBar / focus / selected nav)
  static const Color brand = Color(0xFF0F766E);
  static const Color brandDark = Color(0xFF0B5A54);
  static const Color brandSoft = Color(0xFFD5EFEB);

  /// Alias kept for call sites — chrome/selection/focus.
  static const Color primary = brand;
  static const Color primaryDark = brandDark;
  static const Color primaryLight = brandSoft;

  /// Coral CTAs (ElevatedButton, FAB, Assign / Add).
  static const Color accent = Color(0xFFE76F51);
  static const Color accentDark = Color(0xFFCF5A3D);
  static const Color accentSoft = Color(0xFFFCE8E2);
  static const Color cta = accent;
  static const Color ctaDark = accentDark;

  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onCta = Color(0xFFFFFFFF);

  // Page & card surfaces
  static const Color background = Color(0xFFF4F8F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = surface;

  // Legacy aliases (warm charcoal era → mapped into B+)
  static const Color dark = Color(0xFF14201E);
  static const Color light = background;
  static const Color darkBrown = brand;

  // Hover / selected row & menu highlight
  static const Color hover = brandSoft;
  static const Color highlight = hover;

  static const Color textDark = Color(0xFF14201E);
  static const Color textMuted = Color(0xFF5B6B68);
  static const Color textLight = Color(0xFFFFFFFF);

  static const Color slate900 = textDark;
  static const Color slate800 = Color(0xFF1E2E2C);
  static const Color slate700 = Color(0xFF3A4A47);
  static const Color slate600 = Color(0xFF5B6B68);
  static const Color slate500 = Color(0xFF7A8A87);
  static const Color slate400 = Color(0xFF9AA9A6);
  static const Color slate300 = Color(0xFFBCC9C6);
  static const Color slate200 = Color(0xFFD5E2DF);
  static const Color slate100 = background;

  static const Color error = Color(0xFFDC2626);
  static const Color errorBackground = Color(0xFFFEF2F2);

  static const Color success = Color(0xFF16A34A);
  static const Color successBackground = Color(0xFFF0FDF4);

  /// Open roster slot indicators (warm amber — not error-red).
  static const Color openSlot = Color(0xFFB45309);
  static const Color openSlotBackground = Color(0xFFFFF7ED);

  /// Incomplete / needs-attention wash (coral soft).
  static const Color incompleteBackground = accentSoft;

  static const Color divider = slate200;
}
