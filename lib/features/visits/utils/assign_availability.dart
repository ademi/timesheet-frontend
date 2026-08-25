import '../../shifts/data/models/shift_models.dart';
import '../data/models/roster_overlay_models.dart';

/// Free / Busy / Leave label for assign pickers (shifts + overlay leave).
///
/// Busy currently reflects overlapping **shift** assignments only; visit overlap
/// is deferred to Task 10 (`assignAvailabilityLabel` + lite visits).
String assignAvailabilityLabel({
  required String contractorId,
  required DateTime day,
  required DateTime shiftStart,
  required DateTime shiftEnd,
  required RosterOverlayOut overlay,
  required List<ShiftOut> shifts,
}) {
  final dayLocal = day.toLocal();
  final civil = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  for (final c in overlay.contractors) {
    if (c.contractorId != contractorId) continue;
    for (final leave in c.leave) {
      final leaveStart = leave.startDate.toLocal();
      final leaveEnd = leave.endDate.toLocal();
      final start = DateTime(
        leaveStart.year,
        leaveStart.month,
        leaveStart.day,
      );
      final end = DateTime(
        leaveEnd.year,
        leaveEnd.month,
        leaveEnd.day,
      );
      if (!civil.isBefore(start) && !civil.isAfter(end)) return 'Leave';
    }
  }
  for (final s in shifts) {
    if (s.status == 'cancelled') continue;
    final overlaps =
        s.scheduledStart.isBefore(shiftEnd) &&
        s.scheduledEnd.isAfter(shiftStart);
    if (!overlaps) continue;
    for (final a in s.assignments) {
      if (a.status == 'active' && a.contractorId == contractorId) {
        return 'Busy';
      }
    }
  }
  return 'Free';
}
