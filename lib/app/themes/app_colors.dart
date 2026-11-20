import 'package:flutter/material.dart';

/// RostIQ forest chrome + mint CTA — aligned with landing `globals.css`.
///
/// Dark forest is the main brand (AppBar / nav / focus). Mint is reserved
/// for primary actions (ElevatedButton, FAB, Assign / Add).
class AppColors {
  AppColors._();

  // Brand chrome (forest rail / AppBar / focus / selected nav)
  static const Color brand = Color(0xFF003624);
  static const Color brandDark = Color(0xFF00291B);
  static const Color brandSoft = Color(0xFFD6EDE4);

  /// Alias kept for call sites — chrome/selection/focus.
  static const Color primary = brand;
  static const Color primaryDark = brandDark;
  static const Color primaryLight = brandSoft;

  /// Mint CTAs (ElevatedButton, FAB, Assign / Add).
  static const Color accent = Color(0xFF00E891);
  static const Color accentDark = Color(0xFF00C978);
  static const Color accentSoft = Color(0xFFE0FCF2);
  static const Color cta = accent;
  static const Color ctaDark = accentDark;

  /// Light text on forest chrome; brand ink on mint CTAs.
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onCta = Color(0xFF003624);

  // Page & card surfaces
  static const Color background = Color(0xFFF3F1EB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = surface;
  static const Color surfaceAlt = Color(0xFFEBE8E0);

  // Legacy aliases → mapped into forest / mint
  static const Color dark = brand;
  static const Color light = background;
  static const Color darkBrown = brand;

  // Hover / selected row & menu highlight
  static const Color hover = brandSoft;
  static const Color highlight = hover;

  static const Color textDark = Color(0xFF12231D);
  static const Color textMuted = Color(0xFF5B6B68);
  static const Color textLight = Color(0xFFFFFFFF);

  static const Color slate900 = textDark;
  static const Color slate800 = Color(0xFF1A2F27);
  static const Color slate700 = Color(0xFF3A4A47);
  static const Color slate600 = Color(0xFF5B6B68);
  static const Color slate500 = Color(0xFF7A8A87);
  static const Color slate400 = Color(0xFF9AA9A6);
  static const Color slate300 = Color(0xFFBCC9C6);
  static const Color slate200 = Color(0xFFD5E2DF);
  static const Color slate100 = background;

  static const Color error = Color(0xFFDC2626);
  static const Color errorBackground = Color(0xFFFEF2F2);

  static const Color success = Color(0xFF00A86B);
  static const Color successBackground = Color(0xFFE6F7F0);

  /// Open roster slot indicators (mint wash).
  static const Color openSlot = Color(0xFF00E891);
  static const Color openSlotBackground = Color(0xFFD6FBED);

  /// Incomplete / needs-attention wash (mint soft).
  static const Color incompleteBackground = accentSoft;

  /// Composer work surface (single scroll plane — not a card kit).
  static const Color workSurface = surface;

  /// Sticky composer footer plane.
  static const Color composerFooter = surface;

  /// Draft status chip (slate, not success/error).
  static const Color draftChip = slate600;
  static const Color draftChipBackground = slate200;

  static const Color divider = slate200;
}
