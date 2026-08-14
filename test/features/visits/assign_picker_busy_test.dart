import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';

void main() {
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
}
