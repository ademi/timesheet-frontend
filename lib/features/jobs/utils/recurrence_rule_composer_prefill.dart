import 'package:flutter/material.dart';

import '../../../shared/widgets/keyboard_time_field.dart';
import '../data/models/job_models.dart';
import 'recurrence_rrule_builder.dart';

/// Parsed schedule fields for Unified Support ongoing composer.
class RecurrenceComposerPrefill {
  const RecurrenceComposerPrefill({
    required this.frequency,
    required this.weekdays,
    required this.startDate,
    required this.startTime,
    required this.endTime,
    required this.requiredSlots,
    this.endDate,
  });

  final RecurrenceFrequency frequency;
  final Set<int> weekdays;
  final DateTime startDate;
  final DateTime? endDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int requiredSlots;
}

const _rruleToWeekday = <String, int>{
  'MO': DateTime.monday,
  'TU': DateTime.tuesday,
  'WE': DateTime.wednesday,
  'TH': DateTime.thursday,
  'FR': DateTime.friday,
  'SA': DateTime.saturday,
  'SU': DateTime.sunday,
};

/// Maps a stored recurrence rule into composer Schedule fields.
///
/// Returns null when the RRULE or first time window cannot be applied.
/// Multi-window rules use the first window only (composer has a single pair).
RecurrenceComposerPrefill? mapRecurrenceRuleToComposerPrefill(
  RecurrenceRuleOut rule,
) {
  final fields = <String, String>{
    for (final field in rule.rrule.split(';'))
      if (field.contains('=')) field.split('=').first: field.split('=').last,
  };
  final freq = fields['FREQ'];
  final interval = fields['INTERVAL'];
  final RecurrenceFrequency frequency;
  final weekdays = <int>{};

  switch (freq) {
    case 'DAILY':
      frequency = RecurrenceFrequency.daily;
    case 'MONTHLY':
      frequency = RecurrenceFrequency.monthly;
    case 'WEEKLY':
      frequency =
          interval == '2'
              ? RecurrenceFrequency.fortnightly
              : RecurrenceFrequency.weekly;
      for (final code in (fields['BYDAY'] ?? '').split(',')) {
        final day = _rruleToWeekday[code.trim()];
        if (day != null) weekdays.add(day);
      }
      if (weekdays.isEmpty) return null;
    default:
      return null;
  }

  if (rule.timeWindows.isEmpty) return null;
  final window = rule.timeWindows.first;
  final startTime = parseHhMm(window.startTime);
  final endTime = parseHhMm(window.endTime);
  if (startTime == null || endTime == null) return null;

  final slots = rule.requiredSlots.clamp(1, 20);
  final startDate = DateTime(
    rule.dtstart.year,
    rule.dtstart.month,
    rule.dtstart.day,
  );
  DateTime? endDate;
  final until = rule.until;
  if (until != null) {
    endDate = DateTime(until.year, until.month, until.day);
  }

  return RecurrenceComposerPrefill(
    frequency: frequency,
    weekdays: weekdays,
    startDate: startDate,
    endDate: endDate,
    startTime: startTime,
    endTime: endTime,
    requiredSlots: slots,
  );
}
