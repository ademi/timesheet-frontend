/// Display formatting for visit / shift dates across the app.
///
/// Date: `2026/10/03 Sat`
/// Date+time: `2026/10/03 Sat 10:12`
library;

const _weekdayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _two(int n) => n.toString().padLeft(2, '0');

String _weekdayShort(DateTime local) => _weekdayAbbr[(local.weekday - 1) % 7];

/// Local calendar date with abbreviated weekday, e.g. `2026/10/03 Sat`.
String formatVisitDate(DateTime dt) {
  final l = dt.toLocal();
  return '${l.year}/${_two(l.month)}/${_two(l.day)} ${_weekdayShort(l)}';
}

/// Local date + `HH:mm` with abbreviated weekday, e.g. `2026/10/03 Sat 10:12`.
String formatVisitDateTime(DateTime dt) {
  final l = dt.toLocal();
  return '${formatVisitDate(l)} ${_two(l.hour)}:${_two(l.minute)}';
}

/// Local time only `HH:mm` (day already shown elsewhere).
String formatVisitTime(DateTime dt) {
  final l = dt.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

/// Range of datetimes, e.g. `2026/10/03 Sat 10:12 – 2026/10/03 Sat 12:12`.
String formatVisitDateTimeRange(DateTime start, DateTime end) =>
    '${formatVisitDateTime(start)} – ${formatVisitDateTime(end)}';

/// Range of dates, e.g. `2026/10/03 Sat – 2026/10/05 Mon`.
String formatVisitDateRange(DateTime start, DateTime end) =>
    '${formatVisitDate(start)} – ${formatVisitDate(end)}';
