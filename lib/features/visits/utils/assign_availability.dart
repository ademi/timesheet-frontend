import '../../../core/time/tenant_civil_time.dart';
import '../../jobs/utils/schedule_conflict.dart';
import '../../shifts/data/models/shift_models.dart';
import '../data/models/roster_overlay_models.dart';
import '../data/models/visit_models.dart';

/// Minutes from midnight for `HH:MM` / `HH:MM:SS` strings.
int? parseAvailabilityTimeToMinutes(String raw) {
  final parts = raw.trim().split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

/// True when [windowStart]–[windowEnd] sits fully inside at least one rule
/// for that weekday. Empty rules = no preference (treated as matching).
bool windowMatchesAvailabilityRules({
  required DateTime day,
  required DateTime windowStart,
  required DateTime windowEnd,
  required List<AvailabilityRuleOut> rules,
}) {
  final dow = day.weekday - DateTime.monday; // 0=Mon .. 6=Sun
  final dayRules =
      rules.where((rule) => rule.dayOfWeek == dow).toList(growable: false);
  if (dayRules.isEmpty) return true;

  final winStart = windowStart.hour * 60 + windowStart.minute;
  var winEnd = windowEnd.hour * 60 + windowEnd.minute;
  if (winEnd <= winStart) {
    // Overnight window: treat end as end-of-day for preference matching.
    winEnd = 24 * 60;
  }

  for (final rule in dayRules) {
    final rStart = parseAvailabilityTimeToMinutes(rule.startTime);
    final rEnd = parseAvailabilityTimeToMinutes(rule.endTime);
    if (rStart == null || rEnd == null) continue;
    if (winStart >= rStart && winEnd <= rEnd) return true;
  }
  return false;
}

ContractorRosterOverlay? overlayForContractor(
  RosterOverlayOut overlay,
  String contractorId,
) {
  for (final c in overlay.contractors) {
    if (c.contractorId == contractorId) return c;
  }
  return null;
}

/// Free / Busy / Leave / Outside hours for assign pickers.
///
/// Priority: Leave → Busy → Outside hours (preferred-hours mismatch) → Free.
/// [windowStart]/[windowEnd] should be civil wall times for Outside hours;
/// when omitted, [shiftStart]/[shiftEnd] local wall times are used.
String assignAvailabilityLabel({
  required String contractorId,
  required DateTime day,
  required DateTime shiftStart,
  required DateTime shiftEnd,
  required RosterOverlayOut overlay,
  required List<ShiftOut> shifts,
  List<VisitOut> visits = const [],
  DateTime? windowStart,
  DateTime? windowEnd,
  String? tenantTimezone,
}) {
  // Callers pass an already-civil calendar day (query.day / occ.civilDay).
  // Do not run it through day.toUtc() + tenantCivilFromUtc — that can shift
  // the date when device offset differs from the tenant.
  final civil = DateTime(day.year, day.month, day.day);
  final contractor = overlayForContractor(overlay, contractorId);

  if (contractor != null) {
    for (final leave in contractor.leave) {
      final leaveStartCivil = isTenantTimezoneConversionApplied(tenantTimezone)
          ? tenantCivilFromUtc(leave.startDate.toUtc(), tenantTimezone)
          : leave.startDate.toLocal();
      final leaveEndCivil = isTenantTimezoneConversionApplied(tenantTimezone)
          ? tenantCivilFromUtc(leave.endDate.toUtc(), tenantTimezone)
          : leave.endDate.toLocal();
      final start = DateTime(
        leaveStartCivil.year,
        leaveStartCivil.month,
        leaveStartCivil.day,
      );
      final end = DateTime(
        leaveEndCivil.year,
        leaveEndCivil.month,
        leaveEndCivil.day,
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

  if (contractor != null &&
      !windowMatchesAvailabilityRules(
        day: civil,
        windowStart: windowStart ?? shiftStart.toLocal(),
        windowEnd: windowEnd ?? shiftEnd.toLocal(),
        rules: contractor.availability,
      )) {
    return 'Outside hours';
  }

  return 'Free';
}
