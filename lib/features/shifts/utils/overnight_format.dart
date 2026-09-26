/// Overnight continuous-shift display helpers (B1).
library;

/// True when [end] falls on a later local calendar day than [start].
bool spansLocalMidnight(DateTime start, DateTime end) {
  final s = start.toLocal();
  final e = end.toLocal();
  final sDay = DateTime(s.year, s.month, s.day);
  final eDay = DateTime(e.year, e.month, e.day);
  return eDay.isAfter(sDay);
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatHm(DateTime dt) {
  final l = dt.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

/// Continuous overnight label, e.g. `21:00 → 07:00 (+1)`.
String formatOvernightRange(DateTime start, DateTime end) {
  final overnight = spansLocalMidnight(start, end);
  final suffix = overnight ? ' (+1)' : '';
  return '${formatHm(start)} → ${formatHm(end)}$suffix';
}

String? shiftKindLabel(String? kind) {
  switch (kind) {
    case 'sleepover':
      return 'Sleepover';
    case 'active_night':
      return 'Active night';
    default:
      return null;
  }
}

/// Versioned SIL house overnight presets for the composer (B1).
class OvernightHouseTemplate {
  const OvernightHouseTemplate({
    required this.id,
    required this.version,
    required this.name,
    required this.shiftKind,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.suggestedSupportItemCode,
  });

  final String id;
  final int version;
  final String name;
  final String shiftKind;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String? suggestedSupportItemCode;
}

/// Built-in versioned house overnight templates (not dual-shift).
const kOvernightHouseTemplates = <OvernightHouseTemplate>[
  OvernightHouseTemplate(
    id: 'sil_sleepover_v1',
    version: 1,
    name: 'SIL sleepover (21:00–07:00)',
    shiftKind: 'sleepover',
    startHour: 21,
    startMinute: 0,
    endHour: 7,
    endMinute: 0,
    suggestedSupportItemCode: '01_832_0138_1_1',
  ),
  OvernightHouseTemplate(
    id: 'sil_active_night_v1',
    version: 1,
    name: 'SIL active night (22:00–06:00)',
    shiftKind: 'active_night',
    startHour: 22,
    startMinute: 0,
    endHour: 6,
    endMinute: 0,
    suggestedSupportItemCode: '01_803_0138_1_1',
  ),
  OvernightHouseTemplate(
    id: 'community_sleepover_v1',
    version: 1,
    name: 'Community sleepover (20:00–08:00)',
    shiftKind: 'sleepover',
    startHour: 20,
    startMinute: 0,
    endHour: 8,
    endMinute: 0,
    suggestedSupportItemCode: '01_010_0107_1_1',
  ),
];
