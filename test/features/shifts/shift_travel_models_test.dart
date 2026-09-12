import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_travel_models.dart';

void main() {
  test('ShiftTravelOut parses decimal strings and claimed state', () {
    final travel = ShiftTravelOut.fromJson({
      'id': 'travel-1',
      'shift_id': 'shift-1',
      'support_item_code': '02_051_0108_1_1',
      'quantity': '10.0000',
      'apportionment_mode': 'equal',
      'nominated_participant_id': null,
      'claimed_export_id': 'export-1',
      'notes': null,
      'created_at': '2026-09-12T00:00:00Z',
      'updated_at': '2026-09-12T00:00:00Z',
    });

    expect(travel.quantity, 10);
    expect(travel.apportionmentMode, TravelApportionmentMode.equal);
    expect(travel.isClaimed, isTrue);
  });

  test('ShiftTravelWrite serializes the full create/update body', () {
    const body = ShiftTravelWrite(
      supportItemCode: '02_051_0108_1_1',
      quantity: '12.5',
      apportionmentMode: TravelApportionmentMode.nominated,
      nominatedParticipantId: 'sp-1',
    );

    expect(body.toJson(), {
      'support_item_code': '02_051_0108_1_1',
      'quantity': '12.5',
      'apportionment_mode': 'nominated',
      'nominated_participant_id': 'sp-1',
    });
  });
}
