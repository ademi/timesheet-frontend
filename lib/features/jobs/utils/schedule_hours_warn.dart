import 'package:flutter/material.dart';

import '../../../core/time/tenant_civil_time.dart';
import 'recurrence_rrule_builder.dart';

const kAtypicalScheduleHoursMessage =
    'Outside usual Mon–Fri 7am–7pm — continue if intentional.';

const _usualStartMinutes = 7 * 60;
const _usualEndMinutes = 19 * 60;

DateTime _scheduleCivil(DateTime value, String? tenantTimezone) {
  final tzId = tenantTimezone?.trim();
  if (tzId == null || tzId.isEmpty || !value.isUtc) {
    return value;
  }
  return tenantCivilFromUtc(value, tzId);
}

bool isWithinUsualBusinessCivil(DateTime civil) {
  final weekday = civil.weekday;
  if (weekday < DateTime.monday || weekday > DateTime.friday) {
    return false;
  }
  final minutes = civil.hour * 60 + civil.minute;
  return minutes >= _usualStartMinutes && minutes < _usualEndMinutes;
}

/// True when [start] or [end] fall outside Mon–Fri 07:00–19:00 (tenant civil).
///
/// Schedule fields are treated as civil [DateTime] values. When [tenantTimezone]
/// is set and the value is UTC, it is converted to tenant civil time; otherwise
/// the components are used as-is (no full device↔tenant TZ rewrite).
bool shouldWarnAtypicalHours({
  required DateTime start,
  required DateTime end,
  String? tenantTimezone,
}) {
  final startCivil = _scheduleCivil(start, tenantTimezone);
  final endCivil = _scheduleCivil(end, tenantTimezone);
  return !isWithinUsualBusinessCivil(startCivil) ||
      !isWithinUsualBusinessCivil(endCivil);
}

DateTime _dateOnWeekday(DateTime anchor, int weekday) {
  final delta = (weekday - anchor.weekday) % 7;
  final day = DateTime(anchor.year, anchor.month, anchor.day);
  return day.add(Duration(days: delta));
}

/// Warn for recurring patterns: weekend days, daily (includes weekends), or
/// times outside the usual Mon–Fri 07:00–19:00 window.
bool shouldWarnAtypicalOngoingSchedule({
  required RecurrenceFrequency frequency,
  required Set<int> weekdays,
  required TimeOfDay startTime,
  required TimeOfDay endTime,
  required DateTime startDate,
  String? tenantTimezone,
}) {
  if (frequency == RecurrenceFrequency.daily) {
    return true;
  }

  if (frequency == RecurrenceFrequency.weekly ||
      frequency == RecurrenceFrequency.fortnightly) {
    for (final day in weekdays) {
      if (day < DateTime.monday || day > DateTime.friday) {
        return true;
      }
    }
  }

  final sampleWeekday = switch (frequency) {
    RecurrenceFrequency.weekly ||
    RecurrenceFrequency.fortnightly =>
      weekdays.isNotEmpty ? weekdays.first : DateTime.monday,
    RecurrenceFrequency.monthly => startDate.weekday,
    RecurrenceFrequency.daily => startDate.weekday,
  };

  final sample = _dateOnWeekday(startDate, sampleWeekday);
  return shouldWarnAtypicalHours(
    start: DateTime(
      sample.year,
      sample.month,
      sample.day,
      startTime.hour,
      startTime.minute,
    ),
    end: DateTime(
      sample.year,
      sample.month,
      sample.day,
      endTime.hour,
      endTime.minute,
    ),
    tenantTimezone: tenantTimezone,
  );
}
