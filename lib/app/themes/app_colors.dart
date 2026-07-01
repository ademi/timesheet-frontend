import 'package:flutter/material.dart';

/// Core palette — warm charcoal (#1E1A14) and cream (#EFECE7).
class AppColors {
  AppColors._();

  // Core
  static const Color dark = Color(0xFF1E1A14);
  static const Color light = Color(0xFFEFECE7);

  static const Color darkBrown = dark;

  // Primary actions (buttons, links, focus rings)
  static const Color primary = dark;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryDark = Color(0xFF2D2820);
  static const Color primaryLight = Color(0xFFDDD8D0);

  static const Color accent = primary;
  static const Color accentDark = primaryDark;
  static const Color accentAlt = primaryLight;

  // Page & card surfaces
  static const Color background = light;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = surface;

  // Hover / selected row & menu highlight
  static const Color hover = primaryLight;
  static const Color highlight = hover;

  static const Color textDark = dark;
  static const Color textMuted = Color(0xFF6B6560);
  static const Color textLight = Color(0xFFFFFFFF);

  static const Color slate900 = dark;
  static const Color slate800 = Color(0xFF2D2820);
  static const Color slate700 = Color(0xFF4A4338);
  static const Color slate600 = Color(0xFF6B6358);
  static const Color slate500 = Color(0xFF8A8278);
  static const Color slate400 = Color(0xFFA9A196);
  static const Color slate300 = Color(0xFFC8C1B8);
  static const Color slate200 = primaryLight;
  static const Color slate100 = light;

  static const Color error = Color(0xFFDC2626);
  static const Color errorBackground = Color(0xFFFEF2F2);

  static const Color success = Color(0xFF16A34A);

  static const Color divider = slate200;
}
