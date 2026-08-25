import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/time/tenant_civil_time.dart';
import 'package:rostiq/features/jobs/utils/partial_assign_preview.dart';
import 'package:rostiq/features/jobs/utils/recurrence_rrule_builder.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';

VisitOut _visit({
  required String contractorId,
  required DateTime start,
  required DateTime end,
}) {
  return VisitOut(
    id: 'visit-$start',
    tenantId: 't',
    jobId: 'j',
    contractorId: contractorId,
    scheduledStart: start,
    scheduledEnd: end,
    status: 'scheduled',
    source: 'manual',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: start,
    updatedAt: start,
  );
}

void main() {
  tearDown(() {
    tenantUtcOffsetOverride = null;
  });

  test('expandUnifiedSupportOccurrences lists weekly days in horizon', () {
    tenantUtcOffsetOverride = (_, __) => Duration.zero;
    final horizonFrom = DateTime.utc(2026, 8, 25);
    final horizonTo = DateTime.utc(2026, 9, 8);
    final occurrences = expandUnifiedSupportOccurrences(
      isOneSession: false,
      oneSessionStart: DateTime.utc(2026, 8, 25, 9),
      oneSessionEnd: DateTime.utc(2026, 8, 25, 12),
      startDate: DateTime(2026, 8, 25),
      endDate: DateTime(2026, 12, 31),
      frequency: RecurrenceFrequency.weekly,
      weekdays: {DateTime.monday, DateTime.wednesday},
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 12, minute: 0),
      horizonFromUtc: horizonFrom,
      horizonToUtc: horizonTo,
      tenantTimezone: 'UTC',
    );
    expect(occurrences.length, 4);
    expect(
      occurrences.map((o) => o.civilDay.weekday).toSet(),
      {DateTime.monday, DateTime.wednesday},
    );
  });

  test('buildPartialAssignPreview lists busy dates per worker', () {
    tenantUtcOffsetOverride = (_, __) => Duration.zero;
    final mon = DateTime.utc(2026, 8, 25, 9);
    final monEnd = DateTime.utc(2026, 8, 25, 12);
    final wed = DateTime.utc(2026, 8, 27, 9);
    final wedEnd = DateTime.utc(2026, 8, 27, 12);
    final preview = buildPartialAssignPreview(
      contractorIds: ['worker-a', 'worker-b'],
      displayNameFor: (id) => id == 'worker-a' ? 'Alex' : 'Blair',
      occurrences: [
        ScheduleOccurrence(
          startUtc: mon,
          endUtc: monEnd,
          civilDay: DateTime(2026, 8, 25),
        ),
        ScheduleOccurrence(
          startUtc: wed,
          endUtc: wedEnd,
          civilDay: DateTime(2026, 8, 27),
        ),
      ],
      overlay: const RosterOverlayOut(contractors: []),
      shifts: const [],
      visits: [
        _visit(contractorId: 'worker-a', start: mon, end: monEnd),
        _visit(contractorId: 'worker-b', start: wed, end: wedEnd),
      ],
    );
    expect(preview, hasLength(2));
    expect(preview[0].displayName, 'Alex');
    expect(preview[0].skipDates, [DateTime(2026, 8, 25)]);
    expect(preview[1].displayName, 'Blair');
    expect(preview[1].skipDates, [DateTime(2026, 8, 27)]);
  });

  test('formatPartialAssignDate uses short weekday label', () {
    expect(
      formatPartialAssignDate(DateTime(2026, 8, 26)),
      'Wed 26 Aug',
    );
  });
}
