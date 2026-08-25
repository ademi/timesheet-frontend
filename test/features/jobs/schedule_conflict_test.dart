import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/utils/schedule_conflict.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/utils/assign_availability.dart';

VisitOut _visit({
  required String id,
  required String contractorId,
  required DateTime start,
  required DateTime end,
  String status = 'scheduled',
}) {
  return VisitOut(
    id: id,
    tenantId: 't',
    jobId: 'j',
    contractorId: contractorId,
    scheduledStart: start,
    scheduledEnd: end,
    status: status,
    source: 'manual',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: start,
    updatedAt: start,
  );
}

ShiftOut _shift({
  required String id,
  required DateTime start,
  required DateTime end,
  int openSlots = 1,
  String status = 'published',
}) {
  return ShiftOut(
    id: id,
    tenantId: 't',
    jobId: 'standing-job',
    jobTitle: 'Support',
    clientId: 'client-1',
    clientName: 'Sam',
    scheduledStart: start,
    scheduledEnd: end,
    requiredSlots: 1,
    openSlots: openSlots,
    status: status,
    createdAt: start,
    updatedAt: start,
  );
}

void main() {
  test('visitsOverlap detects half-open overlap', () {
    expect(
      rangesOverlap(
        DateTime.utc(2026, 8, 25, 9),
        DateTime.utc(2026, 8, 25, 12),
        DateTime.utc(2026, 8, 25, 11),
        DateTime.utc(2026, 8, 25, 13),
      ),
      isTrue,
    );
    expect(
      rangesOverlap(
        DateTime.utc(2026, 8, 25, 9),
        DateTime.utc(2026, 8, 25, 12),
        DateTime.utc(2026, 8, 25, 12),
        DateTime.utc(2026, 8, 25, 13),
      ),
      isFalse,
    );
  });

  test('assignAvailabilityLabel returns Busy for overlapping visit', () {
    final start = DateTime.utc(2026, 8, 25, 9);
    final end = DateTime.utc(2026, 8, 25, 12);
    expect(
      assignAvailabilityLabel(
        contractorId: 'ali',
        day: DateTime(2026, 8, 25),
        shiftStart: start,
        shiftEnd: end,
        overlay: const RosterOverlayOut(contractors: []),
        shifts: const [],
        visits: [
          _visit(
            id: 'v-busy',
            contractorId: 'ali',
            start: DateTime.utc(2026, 8, 25, 11),
            end: DateTime.utc(2026, 8, 25, 13),
          ),
        ],
      ),
      'Busy',
    );
    expect(
      assignAvailabilityLabel(
        contractorId: 'mo',
        day: DateTime(2026, 8, 25),
        shiftStart: start,
        shiftEnd: end,
        overlay: const RosterOverlayOut(contractors: []),
        shifts: const [],
        visits: [
          _visit(
            id: 'v-busy',
            contractorId: 'ali',
            start: DateTime.utc(2026, 8, 25, 11),
            end: DateTime.utc(2026, 8, 25, 13),
          ),
        ],
      ),
      'Free',
    );
  });

  test('clientConflicts includes unfilled shift overlapping window', () {
    final windowStart = DateTime.utc(2026, 8, 25, 9);
    final windowEnd = DateTime.utc(2026, 8, 25, 12);
    final conflicts = buildClientConflicts(
      windowStart: windowStart,
      windowEnd: windowEnd,
      visits: const [],
      shifts: [
        _shift(
          id: 'hole-1',
          start: DateTime.utc(2026, 8, 25, 10),
          end: DateTime.utc(2026, 8, 25, 13),
          openSlots: 1,
        ),
        _shift(
          id: 'filled',
          start: DateTime.utc(2026, 8, 25, 10),
          end: DateTime.utc(2026, 8, 25, 13),
          openSlots: 0,
        ),
        _shift(
          id: 'outside',
          start: DateTime.utc(2026, 8, 25, 13),
          end: DateTime.utc(2026, 8, 25, 15),
          openSlots: 2,
        ),
      ],
    );
    expect(conflicts.map((c) => c.id), ['hole-1']);
    expect(conflicts.single.kind, ClientConflictKind.shiftHole);
    expect(conflicts.single.chipLabel, 'Open shift hole…');
  });
}
