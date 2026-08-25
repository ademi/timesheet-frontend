import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/time/tenant_civil_time.dart';
import 'package:rostiq/features/jobs/utils/recurrence_rrule_builder.dart';
import 'package:rostiq/features/jobs/utils/schedule_hours_warn.dart';

void main() {
  tearDown(() {
    tenantUtcOffsetOverride = null;
  });

  group('shouldWarnAtypicalHours', () {
    test('warns Saturday morning', () {
      expect(
        shouldWarnAtypicalHours(
          start: DateTime(2026, 8, 22, 9), // Saturday
          end: DateTime(2026, 8, 22, 12),
        ),
        isTrue,
      );
    });

    test('no warn Tuesday 10-14', () {
      expect(
        shouldWarnAtypicalHours(
          start: DateTime(2026, 8, 25, 10), // Tuesday
          end: DateTime(2026, 8, 25, 14),
        ),
        isFalse,
      );
    });

    test('warns Tuesday before 7am', () {
      expect(
        shouldWarnAtypicalHours(
          start: DateTime(2026, 8, 25, 6, 30),
          end: DateTime(2026, 8, 25, 9),
        ),
        isTrue,
      );
    });

    test('warns Tuesday at or after 7pm', () {
      expect(
        shouldWarnAtypicalHours(
          start: DateTime(2026, 8, 25, 10),
          end: DateTime(2026, 8, 25, 19),
        ),
        isTrue,
      );
    });

    test('uses tenant civil weekday when timezone is set on UTC instants', () {
      tenantUtcOffsetOverride = (_, __) => const Duration(hours: 10);
      // Fri 20:00 UTC -> Sat 06:00 Sydney (+10) — outside Mon–Fri 7–19.
      expect(
        shouldWarnAtypicalHours(
          start: DateTime.utc(2026, 8, 21, 20),
          end: DateTime.utc(2026, 8, 21, 22),
          tenantTimezone: 'Australia/Sydney',
        ),
        isTrue,
      );
    });
  });

  group('shouldWarnAtypicalOngoingSchedule', () {
    test('warns when a selected weekday is Saturday', () {
      expect(
        shouldWarnAtypicalOngoingSchedule(
          frequency: RecurrenceFrequency.weekly,
          weekdays: {DateTime.monday, DateTime.saturday},
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 12, minute: 0),
          startDate: DateTime(2026, 8, 25),
        ),
        isTrue,
      );
    });

    test('warns for daily recurrence (includes weekends)', () {
      expect(
        shouldWarnAtypicalOngoingSchedule(
          frequency: RecurrenceFrequency.daily,
          weekdays: const {},
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 12, minute: 0),
          startDate: DateTime(2026, 8, 25),
        ),
        isTrue,
      );
    });

    test('no warn Mon 9-12 weekly', () {
      expect(
        shouldWarnAtypicalOngoingSchedule(
          frequency: RecurrenceFrequency.weekly,
          weekdays: {DateTime.monday},
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 12, minute: 0),
          startDate: DateTime(2026, 8, 25),
        ),
        isFalse,
      );
    });
  });
}
