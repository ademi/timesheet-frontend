import 'humanize_label.dart';

/// Select / multiselect option: persist [value], show [label].
///
/// Backend may send plain strings (`"Male"`) or
/// `{ "value": "plan_managed", "label": "Plan Managed" }`.
class SelectOptionEntry {
  const SelectOptionEntry({required this.value, required this.label});

  final String value;
  final String label;
}

/// Parses [raw] list from `options` / `choices` (schema JSON).
List<SelectOptionEntry> parseSelectOptionList(dynamic raw) {
  if (raw is! List) return const [];
  final out = <SelectOptionEntry>[];
  for (final e in raw) {
    final parsed = parseSelectOption(e);
    if (parsed != null) out.add(parsed);
  }
  return out;
}

/// Parses one option. Returns null when empty / unusable.
SelectOptionEntry? parseSelectOption(dynamic e) {
  if (e is Map) {
    final map = Map<Object?, Object?>.from(e);
    final value =
        (map['value'] ?? map['id'] ?? '').toString().trim();
    final labelField = (map['label'] ?? '').toString().trim();

    if (value.isEmpty) {
      // Legacy object with only label — treat as plain human string.
      if (labelField.isEmpty) return null;
      return SelectOptionEntry(
        value: labelField,
        label: _displayForPlainOrCode(labelField),
      );
    }

    final label =
        labelField.isNotEmpty ? labelField : _displayForPlainOrCode(value);
    return SelectOptionEntry(value: value, label: label);
  }

  final value = e.toString().trim();
  if (value.isEmpty) return null;
  return SelectOptionEntry(value: value, label: _displayForPlainOrCode(value));
}

/// Label for a stored wire [value] given known [entries].
String labelForStoredSelectValue(
  String value, {
  List<SelectOptionEntry> entries = const [],
}) {
  for (final opt in entries) {
    if (opt.value == value) return opt.label;
  }
  return _displayForPlainOrCode(value);
}

String _displayForPlainOrCode(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return s;
  // Already-human plain strings (e.g. "Male", "Friend/Family") stay as-is.
  // Legacy snake_case codes get Title Case via [humanizeLabel].
  if (s.contains('_') || s.contains('-') || s.contains('.')) {
    return humanizeLabel(s);
  }
  return s;
}
