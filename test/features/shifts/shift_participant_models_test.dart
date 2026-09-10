import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_participant_models.dart';

void main() {
  test('ShiftParticipantOut parses percentage row', () {
    final p = ShiftParticipantOut.fromJson({
      'id': 'sp1',
      'shift_id': 's1',
      'participant_id': 'c1',
      'allocation_strategy': 'percentage',
      'allocation_value': 60,
      'status': 'active',
      'time_windows': null,
      'created_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-01T00:00:00Z',
    });
    expect(p.participantId, 'c1');
    expect(p.allocationValue, 60);
    expect(p.timeWindows, isNull);
  });

  test('ShiftParticipantCreateRequest serializes time_based', () {
    final body = ShiftParticipantCreateRequest(
      participantId: 'c1',
      allocationStrategy: 'time_based',
      allocationValue: 0,
      reason: 'Windowed support',
      timeWindows: [
        ShiftParticipantAllocationWindow(
          participantStartTime: DateTime.utc(2026, 9, 10, 1),
          participantEndTime: DateTime.utc(2026, 9, 10, 3),
        ),
      ],
    ).toJson();
    expect(body['allocation_strategy'], 'time_based');
    expect(body['allocation_value'], 0);
    expect(body['time_windows'], hasLength(1));
    expect(body['reason'], 'Windowed support');
  });

  test('AllocationChangeLogOut parses', () {
    final e = AllocationChangeLogOut.fromJson({
      'id': 'a1',
      'shift_id': 's1',
      'change_type': 'participant_added',
      'participant_id': 'c1',
      'old_allocation_value': null,
      'new_allocation_value': 100,
      'old_allocation_strategy': null,
      'new_allocation_strategy': 'percentage',
      'change_reason': 'Initial',
      'changed_by_user_id': 'u1',
      'created_at': '2026-09-01T00:00:00Z',
    });
    expect(e.changeType, 'participant_added');
    expect(e.changeReason, 'Initial');
  });
}
