/// ISO DateTime window validation for group-shift time-based allocation.
///
/// Do not reuse jobs HH:mm [validateVisitWindows] — shift windows use full
/// instants and must stay within [shiftStart, shiftEnd].

class ParticipantWindowDraft {
  const ParticipantWindowDraft({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  ParticipantWindowDraft copyWith({DateTime? start, DateTime? end}) {
    return ParticipantWindowDraft(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  Map<String, dynamic> toApiJson() => {
    'participant_start_time': start.toUtc().toIso8601String(),
    'participant_end_time': end.toUtc().toIso8601String(),
  };
}

/// Seeds a single full-shift window.
List<ParticipantWindowDraft> defaultFullShiftWindows(
  DateTime shiftStart,
  DateTime shiftEnd,
) =>
    [ParticipantWindowDraft(start: shiftStart, end: shiftEnd)];

/// Per-window or set-level error; `null` when valid.
String? validateParticipantWindows(
  List<ParticipantWindowDraft> windows, {
  required DateTime shiftStart,
  required DateTime shiftEnd,
}) {
  if (windows.isEmpty) {
    return 'Add at least one time window';
  }

  for (var i = 0; i < windows.length; i++) {
    final w = windows[i];
    final rowErr = validateSingleWindow(
      w,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
    );
    if (rowErr != null) return rowErr;
  }

  final sorted = [...windows]
    ..sort((a, b) => a.start.compareTo(b.start));
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].start.isBefore(sorted[i - 1].end)) {
      return 'Time windows must not overlap';
    }
  }
  return null;
}

/// Bounds + ordering for one window (inline row errors).
String? validateSingleWindow(
  ParticipantWindowDraft window, {
  required DateTime shiftStart,
  required DateTime shiftEnd,
}) {
  if (!window.end.isAfter(window.start)) {
    return 'End must be after start';
  }
  if (window.start.isBefore(shiftStart)) {
    return 'Start ${_fmtHm(window.start)} is before shift start ${_fmtHm(shiftStart)}';
  }
  if (window.end.isAfter(shiftEnd)) {
    return 'End ${_fmtHm(window.end)} is after shift end ${_fmtHm(shiftEnd)}';
  }
  return null;
}

/// Compact list subtitle, e.g. `10:00–12:00 · 12:30–14:00`.
String formatWindowsSummary(List<ParticipantWindowDraft> windows) {
  if (windows.isEmpty) return 'No windows';
  final sorted = [...windows]..sort((a, b) => a.start.compareTo(b.start));
  return sorted.map((w) => '${_fmtHm(w.start)}–${_fmtHm(w.end)}').join(' · ');
}

String formatShiftBoundsHint(DateTime shiftStart, DateTime shiftEnd) =>
    'Shift bounds ${_fmtHm(shiftStart)}–${_fmtHm(shiftEnd)}';

String _fmtHm(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}';
}
