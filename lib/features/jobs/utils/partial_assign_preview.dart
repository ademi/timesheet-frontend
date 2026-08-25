import 'package:flutter/material.dart';

import '../../../core/time/tenant_civil_time.dart';
import '../../visits/utils/assign_availability.dart';
import '../../visits/utils/assign_schedule_window.dart';
import '../../shifts/data/models/shift_models.dart';
import '../../visits/data/models/roster_overlay_models.dart';
import '../../visits/data/models/visit_models.dart';
import 'recurrence_rrule_builder.dart';

/// One proposed occurrence in the fill horizon.
class ScheduleOccurrence {
  const ScheduleOccurrence({
    required this.startUtc,
    required this.endUtc,
    required this.civilDay,
  });

  final DateTime startUtc;
  final DateTime endUtc;

  /// Tenant-local calendar date (date-only).
  final DateTime civilDay;
}

class PartialAssignWorkerPreview {
  const PartialAssignWorkerPreview({
    required this.displayName,
    required this.skipDates,
  });

  final String displayName;
  final List<DateTime> skipDates;
}

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatPartialAssignDate(DateTime civilDay) {
  return '${_weekdayLabels[civilDay.weekday - DateTime.monday]} '
      '${civilDay.day} ${_monthLabels[civilDay.month - 1]}';
}

bool _matchesRecurrenceDay({
  required DateTime civilDay,
  required DateTime patternStart,
  required RecurrenceFrequency frequency,
  required Set<int> weekdays,
}) {
  if (civilDay.isBefore(
    DateTime(patternStart.year, patternStart.month, patternStart.day),
  )) {
    return false;
  }
  final matchesDay = frequency == RecurrenceFrequency.daily ||
      frequency == RecurrenceFrequency.monthly ||
      weekdays.contains(civilDay.weekday);
  final fortnight = frequency != RecurrenceFrequency.fortnightly ||
      civilDay.difference(patternStart).inDays ~/ 7 % 2 == 0;
  final monthly = frequency != RecurrenceFrequency.monthly ||
      civilDay.day == patternStart.day;
  return matchesDay && fortnight && monthly;
}

/// Occurrences that would be generated inside `[horizonFromUtc, horizonToUtc)`.
List<ScheduleOccurrence> expandUnifiedSupportOccurrences({
  required bool isOneSession,
  required DateTime oneSessionStart,
  required DateTime oneSessionEnd,
  required DateTime startDate,
  required DateTime endDate,
  required RecurrenceFrequency frequency,
  required Set<int> weekdays,
  required TimeOfDay startTime,
  required TimeOfDay endTime,
  required DateTime horizonFromUtc,
  required DateTime horizonToUtc,
  required String? tenantTimezone,
}) {
  if (isOneSession) {
    final startUtc = tenantCivilInstantUtc(oneSessionStart, tenantTimezone);
    final endUtc = tenantCivilInstantUtc(oneSessionEnd, tenantTimezone);
    if (!startUtc.isBefore(horizonToUtc) || !endUtc.isAfter(horizonFromUtc)) {
      return const [];
    }
    final civil = tenantCivilFromUtc(startUtc, tenantTimezone);
    return [
      ScheduleOccurrence(
        startUtc: startUtc,
        endUtc: endUtc,
        civilDay: DateTime(civil.year, civil.month, civil.day),
      ),
    ];
  }

  final patternStart = DateTime(
    startDate.year,
    startDate.month,
    startDate.day,
  );
  final patternEnd = DateTime(endDate.year, endDate.month, endDate.day);
  var civilDay = tenantCivilFromUtc(horizonFromUtc, tenantTimezone);
  civilDay = DateTime(civilDay.year, civilDay.month, civilDay.day);
  final horizonEndCivil = tenantCivilFromUtc(
    horizonToUtc.subtract(const Duration(microseconds: 1)),
    tenantTimezone,
  );
  final lastCivil = DateTime(
    horizonEndCivil.year,
    horizonEndCivil.month,
    horizonEndCivil.day,
  );

  final out = <ScheduleOccurrence>[];
  while (!civilDay.isAfter(lastCivil)) {
    if (!civilDay.isAfter(patternEnd) &&
        _matchesRecurrenceDay(
          civilDay: civilDay,
          patternStart: patternStart,
          frequency: frequency,
          weekdays: weekdays,
        )) {
      final startCivil = DateTime(
        civilDay.year,
        civilDay.month,
        civilDay.day,
        startTime.hour,
        startTime.minute,
      );
      final endCivil = DateTime(
        civilDay.year,
        civilDay.month,
        civilDay.day,
        endTime.hour,
        endTime.minute,
      );
      final startUtc = tenantCivilInstantUtc(startCivil, tenantTimezone);
      final endUtc = tenantCivilInstantUtc(endCivil, tenantTimezone);
      if (startUtc.isBefore(horizonToUtc) && endUtc.isAfter(horizonFromUtc)) {
        out.add(
          ScheduleOccurrence(
            startUtc: startUtc,
            endUtc: endUtc,
            civilDay: civilDay,
          ),
        );
      }
    }
    civilDay = civilDay.add(const Duration(days: 1));
  }
  return out;
}

/// Workers and dates where an overlapping visit/shift would skip assignment.
List<PartialAssignWorkerPreview> buildPartialAssignPreview({
  required List<String> contractorIds,
  required String? Function(String contractorId) displayNameFor,
  required List<ScheduleOccurrence> occurrences,
  required RosterOverlayOut overlay,
  required List<ShiftOut> shifts,
  required List<VisitOut> visits,
}) {
  if (contractorIds.isEmpty || occurrences.isEmpty) return const [];

  final previews = <PartialAssignWorkerPreview>[];
  for (final contractorId in contractorIds) {
    final skipDates = <DateTime>{};
    for (final occ in occurrences) {
      if (assignAvailabilityLabel(
            contractorId: contractorId,
            day: occ.civilDay,
            shiftStart: occ.startUtc,
            shiftEnd: occ.endUtc,
            overlay: overlay,
            shifts: shifts,
            visits: visits,
          ) ==
          'Busy') {
        skipDates.add(occ.civilDay);
      }
    }
    if (skipDates.isEmpty) continue;
    final sorted = skipDates.toList()..sort((a, b) => a.compareTo(b));
    previews.add(
      PartialAssignWorkerPreview(
        displayName: displayNameFor(contractorId) ?? contractorId,
        skipDates: sorted,
      ),
    );
  }
  return previews;
}
