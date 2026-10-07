/// Turns wire/enum codes into readable Title Case labels for lists & dropdowns.
///
/// Examples:
/// - `other_health_qualification` → `Other Health Qualification`
/// - `pending_docs` → `Pending Docs`
/// - `cpr` → `CPR`
///
/// Leaves technical codes unchanged (NDIS support items, UUIDs).
library;

const _acronyms = {
  'cpr',
  'ndis',
  'wwcc',
  'abn',
  'au',
  'sil',
  'gps',
  'iii',
  'ii',
  'iv',
};

final _ndisItemCode = RegExp(r'^\d{2}_\d{3}_');
final _uuidPrefix = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-',
);

/// True when [value] should stay raw (support item numbers, ids).
bool looksLikeTechnicalCode(String value) {
  final s = value.trim();
  if (s.isEmpty) return false;
  if (_ndisItemCode.hasMatch(s)) return true;
  if (_uuidPrefix.hasMatch(s)) return true;
  return false;
}

/// Human-readable label: words split on `_` / `-` / `.`, each Capitalized.
String humanizeLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  if (looksLikeTechnicalCode(trimmed)) return trimmed;

  final parts =
      trimmed
          .replaceAll('.', '_')
          .replaceAll('-', '_')
          .split('_')
          .where((p) => p.isNotEmpty);

  return parts.map(_titleWord).join(' ');
}

String _titleWord(String word) {
  final lower = word.toLowerCase();
  if (_acronyms.contains(lower)) {
    if (lower == 'iii' || lower == 'ii' || lower == 'iv') {
      return lower.toUpperCase();
    }
    return lower.toUpperCase();
  }
  if (lower.length == 1) return lower.toUpperCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}
