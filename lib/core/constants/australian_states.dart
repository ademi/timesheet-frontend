/// Australian states and territories (abbreviated codes).
const kAustralianStates = <String>[
  'NSW',
  'VIC',
  'QLD',
  'WA',
  'SA',
  'TAS',
  'ACT',
  'NT',
];

const kDefaultAustralianState = 'NSW';

bool isAustralianState(String? value) {
  if (value == null) return false;
  return kAustralianStates.contains(value.trim().toUpperCase());
}

/// Returns [value] when it is a known AU state code, otherwise [fallback].
String normalizeAustralianState(
  String? value, {
  String fallback = kDefaultAustralianState,
}) {
  if (value == null || value.trim().isEmpty) return fallback;
  final upper = value.trim().toUpperCase();
  return kAustralianStates.contains(upper) ? upper : fallback;
}

/// Dropdown items: known states plus a legacy/unknown current value when needed.
List<String> australianStateItems(String? current) {
  final trimmed = current?.trim() ?? '';
  final upper = trimmed.toUpperCase();
  return {
    if (trimmed.isNotEmpty && !kAustralianStates.contains(upper)) trimmed,
    ...kAustralianStates,
  }.toList();
}
