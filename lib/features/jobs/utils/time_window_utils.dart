import '../data/models/job_models.dart';

const endBeforeStartError =
    'End must be after start on the same day. Overnight windows are not supported here.';
const windowsOverlapError = 'Visit windows must be ordered and not overlap.';

String coerceEndTime(String hhmm) {
  if (hhmm == '00:00') return '23:59';
  return hhmm;
}

List<TimeWindow> coerceWindowEndTimes(List<TimeWindow> windows) => [
  for (final window in windows)
    TimeWindow(startTime: window.startTime, endTime: coerceEndTime(window.endTime)),
];

String? validateVisitWindows(List<TimeWindow> windows) {
  final sorted =
      coerceWindowEndTimes(windows).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
  if (sorted.any((window) => window.endTime.compareTo(window.startTime) <= 0)) {
    return endBeforeStartError;
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
