import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_participant_models.dart';
import 'package:rostiq/features/shifts/utils/allocation_math.dart';

void main() {
  group('allocation_math', () {
    test('sums active percentage participants only', () {
      final parts = [
        ShiftParticipantOut(
          id: 'sp1',
          shiftId: 's1',
          participantId: 'c1',
          allocationStrategy: 'percentage',
          allocationValue: 60,
          status: 'active',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        ShiftParticipantOut(
          id: 'sp2',
          shiftId: 's1',
          participantId: 'c2',
          allocationStrategy: 'percentage',
          allocationValue: 40,
          status: 'removed',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      expect(sumActivePercentage(parts), 60);
      expect(remainingPercentage(parts), 40);
      expect(isPublishReadyPercentage(parts), isFalse);
    });

    test('publish ready when active percentages sum to 100', () {
      final parts = [
        ShiftParticipantOut(
          id: 'sp1',
          shiftId: 's1',
          participantId: 'c1',
          allocationStrategy: 'percentage',
          allocationValue: 60,
          status: 'active',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        ShiftParticipantOut(
          id: 'sp2',
          shiftId: 's1',
          participantId: 'c2',
          allocationStrategy: 'percentage',
          allocationValue: 40,
          status: 'active',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      expect(isPublishReadyPercentage(parts), isTrue);
    });

    test('time_based publish ready when every active has ≥1 window', () {
      final ready = [
        ShiftParticipantOut(
          id: 'sp1',
          shiftId: 's1',
          participantId: 'c1',
          allocationStrategy: 'time_based',
          allocationValue: 0,
          status: 'active',
          timeWindows: [
            ShiftParticipantAllocationOut(
              id: 'w1',
              shiftParticipantId: 'sp1',
              participantStartTime: DateTime.utc(2026, 1, 1, 1),
              participantEndTime: DateTime.utc(2026, 1, 1, 2),
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          ],
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      expect(isPublishReadyTimeBased(ready), isTrue);
      expect(
        isPublishReadyTimeBased([
          ready.first.copyWith(timeWindows: const []),
        ]),
        isFalse,
      );
    });
  });
}
