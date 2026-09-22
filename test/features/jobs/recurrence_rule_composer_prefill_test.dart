import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/utils/recurrence_rrule_builder.dart';
import 'package:rostiq/features/jobs/utils/recurrence_rule_composer_prefill.dart';

RecurrenceRuleOut _rule({
  required String rrule,
  List<TimeWindow> windows = const [
    TimeWindow(startTime: '09:00', endTime: '12:00'),
  ],
  DateTime? dtstart,
  DateTime? until,
  int requiredSlots = 1,
}) {
  final start = dtstart ?? DateTime(2026, 3, 2, 9);
  return RecurrenceRuleOut(
    id: 'rule-1',
    tenantId: 't',
    jobId: 'job-1',
    requiredSlots: requiredSlots,
    rrule: rrule,
    dtstart: start,
    until: until,
    timeWindows: windows,
    isActive: true,
    createdAt: start,
    updatedAt: start,
  );
}

void main() {
  test('maps weekly BYDAY and first window', () {
    final prefill = mapRecurrenceRuleToComposerPrefill(
      _rule(
        rrule: 'FREQ=WEEKLY;BYDAY=MO,WE',
        windows: const [
          TimeWindow(startTime: '10:30', endTime: '14:00'),
          TimeWindow(startTime: '15:00', endTime: '16:00'),
        ],
        until: DateTime(2027, 3, 2),
        requiredSlots: 2,
      ),
    );
    expect(prefill, isNotNull);
    expect(prefill!.frequency, RecurrenceFrequency.weekly);
    expect(prefill.weekdays, {DateTime.monday, DateTime.wednesday});
    expect(prefill.startTime, const TimeOfDay(hour: 10, minute: 30));
    expect(prefill.endTime, const TimeOfDay(hour: 14, minute: 0));
    expect(prefill.requiredSlots, 2);
    expect(prefill.endDate, DateTime(2027, 3, 2));
  });

  test('maps fortnightly and daily', () {
    expect(
      mapRecurrenceRuleToComposerPrefill(
        _rule(rrule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=FR'),
      )!.frequency,
      RecurrenceFrequency.fortnightly,
    );
    expect(
      mapRecurrenceRuleToComposerPrefill(
        _rule(rrule: 'FREQ=DAILY'),
      )!.frequency,
      RecurrenceFrequency.daily,
    );
    expect(
      mapRecurrenceRuleToComposerPrefill(
        _rule(rrule: 'FREQ=MONTHLY'),
      )!.frequency,
      RecurrenceFrequency.monthly,
    );
  });

  test('returns null when weekly missing BYDAY or no windows', () {
    expect(
      mapRecurrenceRuleToComposerPrefill(_rule(rrule: 'FREQ=WEEKLY')),
      isNull,
    );
    expect(
      mapRecurrenceRuleToComposerPrefill(
        _rule(rrule: 'FREQ=DAILY', windows: const []),
      ),
      isNull,
    );
    expect(
      mapRecurrenceRuleToComposerPrefill(_rule(rrule: 'FREQ=YEARLY')),
      isNull,
    );
  });

  test('null until leaves endDate null for caller default', () {
    final prefill = mapRecurrenceRuleToComposerPrefill(
      _rule(rrule: 'FREQ=DAILY', until: null),
    );
    expect(prefill!.endDate, isNull);
  });
}
