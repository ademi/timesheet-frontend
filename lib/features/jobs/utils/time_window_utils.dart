import '../data/models/job_models.dart';

const endBeforeStartError =
    'End must be after start on the same day. Overnight windows are not supported here.';
const windowsOverlapError = 'Visit windows must be ordered and not overlap.';

/// Default recurrence end: one civil year after [start] (not open-ended).
DateTime defaultRecurrenceEndDate(DateTime start) {
  return DateTime(start.year + 1, start.month, start.day);
}

/// Inclusive end-of-day instant for API `until` on a civil end date.
DateTime recurrenceUntilInstant(DateTime endDate) {
  return DateTime(endDate.year, endDate.month, endDate.day).add(
    const Duration(days: 1, microseconds: -1),
  );
}

String? validateVisitWindows(List<TimeWindow> windows) {
  final sorted = windows.toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  for (final window in sorted) {
    final end = window.endTime.trim();
    if (end == '00:00') {
      return endBeforeStartError;
    }
    if (end.compareTo(window.startTime.trim()) <= 0) {
      return endBeforeStartError;
    }
  }
  if (sorted
      .skip(1)
      .toList()
      .asMap()
      .entries
      .any(
        (entry) => entry.value.startTime.compareTo(sorted[entry.key].endTime) < 0,
      )) {
    return windowsOverlapError;
  }
  return null;
}
