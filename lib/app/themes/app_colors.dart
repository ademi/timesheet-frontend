import 'package:flutter/material.dart';

/// GoCardless-inspired palette — warm charcoal, cream surfaces, lime CTAs.
class AppColors {
  AppColors._();

  // Dark surfaces (app bars, headers, sidebars)
  static const Color dark = Color(0xFF1E1A14);
  static const Color darkBrown = dark;

  // Primary actions (buttons, links, focus rings)
  static const Color primary = Color(0xFFF4F57D);
  static const Color primaryDark = Color(0xFFDFDC65);
  static const Color primaryLight = Color(0xFFF9FAA5);
  static const Color onPrimary = Color(0xFF1E1A14);

  static const Color accent = primary;
  static const Color accentDark = primaryDark;
  static const Color accentAlt = Color(0xFFEAE8F9);

  // Page & card surfaces
  static const Color background = Color(0xFFEFECE7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = surface;

  // Hover / selected row & menu highlight
  static const Color hover = Color(0xFFEAE8F9);
  static const Color highlight = hover;

  static const Color textDark = Color(0xFF1E1A14);
  static const Color textMuted = Color(0xFF6B6560);
  static const Color textLight = Color(0xFFFFFFFF);

  static const Color slate900 = Color(0xFF1E1A14);
  static const Color slate800 = Color(0xFF2D2820);
  static const Color slate700 = Color(0xFF4A4338);
  static const Color slate600 = Color(0xFF6B6358);
  static const Color slate500 = Color(0xFF8A8278);
  static const Color slate400 = Color(0xFFA9A196);
  static const Color slate300 = Color(0xFFC8C1B8);
  static const Color slate200 = Color(0xFFDDD8D0);
  static const Color slate100 = Color(0xFFEFECE7);

  static const Color error = Color(0xFFDC2626);
  static const Color errorBackground = Color(0xFFFEF2F2);

  static const Color success = Color(0xFF16A34A);

  static const Color divider = slate200;
}
