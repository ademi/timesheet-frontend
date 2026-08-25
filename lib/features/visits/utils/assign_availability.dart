import '../../jobs/utils/schedule_conflict.dart';
import '../../shifts/data/models/shift_models.dart';
import '../data/models/roster_overlay_models.dart';
import '../data/models/visit_models.dart';

/// Free / Busy / Leave label for assign pickers (visits, shifts, overlay leave).
String assignAvailabilityLabel({
  required String contractorId,
  required DateTime day,
  required DateTime shiftStart,
  required DateTime shiftEnd,
  required RosterOverlayOut overlay,
  required List<ShiftOut> shifts,
  List<VisitOut> visits = const [],
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
  for (final v in visits) {
    if (v.isCancelled) continue;
    if (v.contractorId != contractorId) continue;
    if (rangesOverlap(
      v.scheduledStart,
      v.scheduledEnd,
      shiftStart,
      shiftEnd,
    )) {
      return 'Busy';
    }
  }
  for (final s in shifts) {
    if (s.status == 'cancelled') continue;
    final overlaps = rangesOverlap(
      s.scheduledStart,
      s.scheduledEnd,
      shiftStart,
      shiftEnd,
    );
    if (!overlaps) continue;
    for (final a in s.assignments) {
      if (a.status == 'active' && a.contractorId == contractorId) {
        return 'Busy';
      }
    }
  }
  return 'Free';
}
