import 'package:flutter/material.dart';

import '../../../core/time/tenant_civil_time.dart';
import '../../jobs/utils/recurrence_rrule_builder.dart';

/// Proposed support window for assign-step availability (civil wall times).
class AssignScheduleWindow {
  const AssignScheduleWindow({
    required this.dayCivil,
    required this.startCivil,
    required this.endCivil,
  });

  final DateTime dayCivil;
  final DateTime startCivil;
  final DateTime endCivil;
}

DateTime? firstRecurrenceOccurrenceDate({
  required DateTime startDate,
  required RecurrenceFrequency frequency,
  required Set<int> weekdays,
}) {
  var date = DateTime(startDate.year, startDate.month, startDate.day);
  final limit = date.add(const Duration(days: 366));
  while (!date.isAfter(limit)) {
    final matches =
        frequency == RecurrenceFrequency.daily ||
        frequency == RecurrenceFrequency.monthly ||
        weekdays.contains(date.weekday);
    final fortnight =
        frequency != RecurrenceFrequency.fortnightly ||
        date.difference(startDate).inDays ~/ 7 % 2 == 0;
    final monthly =
        frequency != RecurrenceFrequency.monthly || date.day == startDate.day;
    if (!date.isBefore(startDate) && matches && fortnight && monthly) {
      return date;
    }
    date = date.add(const Duration(days: 1));
  }
  return null;
}

AssignScheduleWindow computeAssignScheduleWindow({
  required bool isOneSession,
  required DateTime oneSessionStart,
  required DateTime oneSessionEnd,
  required DateTime startDate,
  required RecurrenceFrequency frequency,
  required Set<int> weekdays,
  required TimeOfDay startTime,
  required TimeOfDay endTime,
}) {
  if (isOneSession) {
    final day = DateTime(
      oneSessionStart.year,
      oneSessionStart.month,
      oneSessionStart.day,
    );
    return AssignScheduleWindow(
      dayCivil: day,
      startCivil: oneSessionStart,
      endCivil: oneSessionEnd,
    );
  }

  final occurrence = firstRecurrenceOccurrenceDate(
    startDate: startDate,
    frequency: frequency,
    weekdays: weekdays,
  );
  final day = occurrence ?? startDate;
  final dayOnly = DateTime(day.year, day.month, day.day);
  return AssignScheduleWindow(
    dayCivil: dayOnly,
    startCivil: DateTime(
      dayOnly.year,
      dayOnly.month,
      dayOnly.day,
      startTime.hour,
      startTime.minute,
    ),
    endCivil: DateTime(
      dayOnly.year,
      dayOnly.month,
      dayOnly.day,
      endTime.hour,
      endTime.minute,
    ),
  );
}

/// UTC query window for roster overlay + shift overlap on the assign step.
({
  DateTime from,
  DateTime to,
  DateTime shiftStart,
  DateTime shiftEnd,
  DateTime day,
  DateTime startCivil,
  DateTime endCivil,
})
assignAvailabilityQueryWindow({
  required AssignScheduleWindow window,
  String? tenantTimezone,
}) {
  final tzId = tenantTimezone?.trim();
  final hasTenantTz = tzId != null && tzId.isNotEmpty;
  final shiftStart = hasTenantTz
      ? tenantCivilInstantUtc(window.startCivil, tzId)
      : window.startCivil;
  final shiftEnd = hasTenantTz
      ? tenantCivilInstantUtc(window.endCivil, tzId)
      : window.endCivil;
  final overlayFrom = hasTenantTz
      ? startOfTenantCivilDayUtc(shiftStart, tzId)
      : DateTime(
          window.dayCivil.year,
          window.dayCivil.month,
          window.dayCivil.day,
        );
  final overlayTo = hasTenantTz
      ? startOfTenantCivilDayUtc(shiftEnd, tzId).add(const Duration(days: 1))
      : overlayFrom.add(const Duration(days: 1));
  return (
    from: overlayFrom,
    to: overlayTo,
    shiftStart: shiftStart,
    shiftEnd: shiftEnd,
    day: window.dayCivil,
    startCivil: window.startCivil,
    endCivil: window.endCivil,
  );
}
