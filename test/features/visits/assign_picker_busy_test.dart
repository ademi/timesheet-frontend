import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/time/tenant_civil_time.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/visits/utils/assign_availability.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';

void main() {
  tearDown(() {
    tenantUtcOffsetOverride = null;
  });

  test('leave uses tenant civil day when device offset differs', () {
    tenantUtcOffsetOverride = (tz, _) {
      if (tz == 'Australia/Sydney') return const Duration(hours: 10);
      return Duration.zero;
    };
    final day = DateTime(2026, 8, 13);
    final leaveStartUtc = tenantCivilDateStartUtc(day, 'Australia/Sydney');
    final overlay = RosterOverlayOut(
      contractors: [
        ContractorRosterOverlay(
          contractorId: 'jane',
          displayName: 'Jane',
          leave: [
            LeaveIntervalOut(
              startDate: leaveStartUtc,
              endDate: leaveStartUtc,
              leaveType: 'annual',
            ),
          ],
          availability: const [],
        ),
      ],
    );
    final shiftStart = DateTime(2026, 8, 13, 9);
    final shiftEnd = DateTime(2026, 8, 13, 12);

    expect(
      assignAvailabilityLabel(
        contractorId: 'jane',
        day: day,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        overlay: overlay,
        shifts: const [],
        tenantTimezone: 'Australia/Sydney',
      ),
      'Leave',
    );

    final dayLocal = DateTime(day.toLocal().year, day.toLocal().month, day.toLocal().day);
    final leaveLocal = leaveStartUtc.toLocal();
    final leaveCivil = DateTime(leaveLocal.year, leaveLocal.month, leaveLocal.day);
    final deviceExpectsLeave =
        !dayLocal.isBefore(leaveCivil) && !dayLocal.isAfter(leaveCivil);
    // On UTC devices leave UTC instant falls on prior civil day without tenant TZ.
    if (DateTime.now().timeZoneOffset == Duration.zero) {
      expect(deviceExpectsLeave, isFalse);
    }
    expect(
      assignAvailabilityLabel(
        contractorId: 'jane',
        day: day,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        overlay: overlay,
        shifts: const [],
      ),
      deviceExpectsLeave ? 'Leave' : 'Free',
    );
  });

  test('assign candidates mark leave and overlapping shift as busy', () {
    final day = DateTime(2026, 8, 13);
    final shiftStart = DateTime(2026, 8, 13, 9);
    final shiftEnd = DateTime(2026, 8, 13, 12);
    final overlay = RosterOverlayOut(
      contractors: [
        ContractorRosterOverlay(
          contractorId: 'jane',
          displayName: 'Jane',
          leave: [
            LeaveIntervalOut(
              startDate: day,
              endDate: day,
              leaveType: 'sick',
            ),
          ],
          availability: const [],
        ),
      ],
    );
    final busyShift = ShiftOut(
      id: 's-busy',
      tenantId: 't',
      jobId: 'j',
      jobTitle: 'Other',
      clientId: 'c',
      clientName: 'Pat',
      scheduledStart: shiftStart,
      scheduledEnd: shiftEnd,
      requiredSlots: 1,
      openSlots: 0,
      status: 'published',
      assignments: [
        ShiftAssignmentOut(
          id: 'a',
          contractorId: 'ali',
          contractorName: 'Ali',
          visitId: 'v',
          source: 'staff_assign',
          status: 'active',
        ),
      ],
      createdAt: day,
      updatedAt: day,
    );
    expect(
      assignAvailabilityLabel(
        contractorId: 'jane',
        day: day,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        overlay: overlay,
        shifts: [busyShift],
      ),
      'Leave',
    );
    expect(
      assignAvailabilityLabel(
        contractorId: 'ali',
        day: day,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        overlay: overlay,
        shifts: [busyShift],
      ),
      'Busy',
    );
    expect(
      assignAvailabilityLabel(
        contractorId: 'mo',
        day: day,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        overlay: overlay,
        shifts: [busyShift],
      ),
      'Free',
    );
  });

  test('Outside hours when proposed window is outside preferred rules', () {
    // Thursday 2026-08-13
    final day = DateTime(2026, 8, 13);
    final overlay = RosterOverlayOut(
      contractors: [
        ContractorRosterOverlay(
          contractorId: 'pat',
          displayName: 'Pat',
          availability: const [
            AvailabilityRuleOut(
              dayOfWeek: 3, // Thu
              startTime: '09:00:00',
              endTime: '17:00:00',
            ),
          ],
        ),
      ],
    );
    expect(
      assignAvailabilityLabel(
        contractorId: 'pat',
        day: day,
        shiftStart: DateTime(2026, 8, 13, 18),
        shiftEnd: DateTime(2026, 8, 13, 20),
        windowStart: DateTime(2026, 8, 13, 18),
        windowEnd: DateTime(2026, 8, 13, 20),
        overlay: overlay,
        shifts: const [],
      ),
      'Outside hours',
    );
    expect(
      assignAvailabilityLabel(
        contractorId: 'pat',
        day: day,
        shiftStart: DateTime(2026, 8, 13, 10),
        shiftEnd: DateTime(2026, 8, 13, 12),
        windowStart: DateTime(2026, 8, 13, 10),
        windowEnd: DateTime(2026, 8, 13, 12),
        overlay: overlay,
        shifts: const [],
      ),
      'Free',
    );
  });

  test('no availability rules means Free (no preference)', () {
    final day = DateTime(2026, 8, 13);
    final overlay = RosterOverlayOut(
      contractors: [
        ContractorRosterOverlay(
          contractorId: 'pat',
          displayName: 'Pat',
          availability: const [],
        ),
      ],
    );
    expect(
      assignAvailabilityLabel(
        contractorId: 'pat',
        day: day,
        shiftStart: DateTime(2026, 8, 13, 22),
        shiftEnd: DateTime(2026, 8, 13, 23),
        windowStart: DateTime(2026, 8, 13, 22),
        windowEnd: DateTime(2026, 8, 13, 23),
        overlay: overlay,
        shifts: const [],
      ),
      'Free',
    );
  });
}
