import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_participant_models.dart';

void main() {
  test('ShiftParticipantBatchCreateRequest serializes participants list', () {
    final body = ShiftParticipantBatchCreateRequest(
      participants: [
        const ShiftParticipantCreateRequest(
          participantId: 'c1',
          allocationStrategy: 'percentage',
          allocationValue: 60,
          reason: 'Initial group split',
        ),
        const ShiftParticipantCreateRequest(
          participantId: 'c2',
          allocationStrategy: 'percentage',
          allocationValue: 40,
          reason: 'Initial group split',
        ),
      ],
    );

    final json = body.toJson();

    expect(json['participants'], hasLength(2));
    expect(json['participants'][0]['participant_id'], 'c1');
    expect(json['participants'][1]['allocation_value'], 40);
  });
}
