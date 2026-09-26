/// Legacy bundled STA ratio day packages — forbidden for publish/export (B13).
///
/// Mirrors BE `app/modules/billing/legacy_sta.py`.
abstract final class LegacyStaRatio {
  LegacyStaRatio._();

  /// 2026-27 catalogue ratio day packages (1:1 / 1:2 / 1:3 / 1:4).
  static const codes = <String>{
    '01_045_0115_1_1',
    '01_051_0115_1_1',
    '01_052_0115_1_1',
    '01_053_0115_1_1',
    '01_054_0115_1_1',
    '01_055_0115_1_1',
    '01_056_0115_1_1',
    '01_057_0115_1_1',
    '01_058_0115_1_1',
    '01_059_0115_1_1',
    '01_060_0115_1_1',
    '01_061_0115_1_1',
    '01_062_0115_1_1',
    '01_063_0115_1_1',
    '01_064_0115_1_1',
    '01_065_0115_1_1',
  };

  static final _namePattern = RegExp(
    r'STA\s+And\s+Assistance\s*\(Inc\.\s*Respite\)\s*-\s*1:\d+',
    caseSensitive: false,
  );

  static bool isLegacyStaRatioItem({String? code, String? name}) {
    final c = code?.trim();
    if (c != null && c.isNotEmpty && codes.contains(c)) return true;
    final n = name?.trim();
    if (n != null && n.isNotEmpty && _namePattern.hasMatch(n)) return true;
    return false;
  }
}
