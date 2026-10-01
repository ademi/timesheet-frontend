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
    expect(travel.claimKind, TravelClaimKind.nonLabour);
    expect(travel.apportionmentMode, TravelApportionmentMode.equal);
    expect(travel.isClaimed, isTrue);
  });

  test('ShiftTravelOut parses labour fields and over_cap', () {
    final travel = ShiftTravelOut.fromJson({
      'id': 'travel-2',
      'shift_id': 'shift-1',
      'claim_kind': 'labour',
      'support_item_code': null,
      'quantity': '0.7500',
      'apportionment_mode': 'equal',
      'nominated_participant_id': null,
      'claimed_export_id': null,
      'notes': null,
      'mmm_category': 1,
      'mmm_cap_minutes': 30,
      'over_cap': true,
      'created_at': '2026-09-12T00:00:00Z',
      'updated_at': '2026-09-12T00:00:00Z',
    });

    expect(travel.isLabour, isTrue);
    expect(travel.supportItemCode, isNull);
    expect(travel.quantity, 0.75);
    expect(travel.mmmCategory, 1);
    expect(travel.mmmCapMinutes, 30);
    expect(travel.overCap, isTrue);
  });

  test('ShiftTravelWrite serializes the full create/update body', () {
    const body = ShiftTravelWrite(
      supportItemCode: '02_051_0108_1_1',
      quantity: '12.5',
      apportionmentMode: TravelApportionmentMode.nominated,
      nominatedParticipantId: 'sp-1',
    );

    expect(body.toJson(), {
      'claim_kind': 'non_labour',
      'support_item_code': '02_051_0108_1_1',
      'quantity': '12.5',
      'apportionment_mode': 'nominated',
      'nominated_participant_id': 'sp-1',
    });
  });

  test('ShiftTravelWrite labour body sends quantity_minutes', () {
    const body = ShiftTravelWrite(
      claimKind: TravelClaimKind.labour,
      quantityMinutes: '45',
      apportionmentMode: TravelApportionmentMode.equal,
    );

    expect(body.toJson(), {
      'claim_kind': 'labour',
      'quantity_minutes': '45',
      'apportionment_mode': 'equal',
      'nominated_participant_id': null,
    });
    expect(body.toJson().containsKey('support_item_code'), isFalse);
    expect(body.toJson().containsKey('quantity'), isFalse);
  });
}
