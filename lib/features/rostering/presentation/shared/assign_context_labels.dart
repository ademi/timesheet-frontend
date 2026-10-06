import '../../../../core/time/tenant_civil_time.dart';
import '../../../jobs/utils/schedule_conflict.dart';
import '../../../visits/utils/assign_availability.dart';
import '../../data/composer_models.dart';

/// Free / Busy / Leave / Outside hours from capped [AssignContextOut].
///
/// Reuses leave + preferred-hours helpers from [assign_availability.dart];
/// Busy uses lite shift/visit rows instead of full ShiftOut/VisitOut lists.
String assignAvailabilityLabelFromContext({
  required String contractorId,
  required DateTime day,
  required DateTime shiftStart,
  required DateTime shiftEnd,
  required AssignContextOut context,
  DateTime? windowStart,
  DateTime? windowEnd,
  String? tenantTimezone,
}) {
  final civil = DateTime(day.year, day.month, day.day);
  final contractor = overlayForContractor(context.overlay, contractorId);

  if (contractor != null) {
    for (final leave in contractor.leave) {
      final leaveStartCivil =
          isTenantTimezoneConversionApplied(tenantTimezone)
              ? tenantCivilFromUtc(leave.startDate.toUtc(), tenantTimezone)
              : leave.startDate.toLocal();
      final leaveEndCivil =
          isTenantTimezoneConversionApplied(tenantTimezone)
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

  for (final v in context.visitsLite) {
    if (v.contractorId != contractorId) continue;
    if (rangesOverlap(v.scheduledStart, v.scheduledEnd, shiftStart, shiftEnd)) {
      return 'Busy';
    }
  }
  for (final s in context.shiftsLite) {
    if (!s.contractorIds.contains(contractorId)) continue;
    if (rangesOverlap(s.scheduledStart, s.scheduledEnd, shiftStart, shiftEnd)) {
      return 'Busy';
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

/// True when [label] requires a staff override reason before assign.
bool assignLabelRequiresOverrideReason(String label) =>
    label == 'Busy' || label == 'Leave';

/// Short chip copy for assign-context [ClientConflictOut] (warn-only).
String clientConflictChipLabel(ClientConflictOut conflict) =>
    switch (conflict.kind) {
      'shift' => 'Open shift hole…',
      _ => 'Overlapping visit…',
    };
