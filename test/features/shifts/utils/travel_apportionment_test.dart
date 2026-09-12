import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_travel_models.dart';
import 'package:rostiq/features/shifts/utils/travel_apportionment.dart';

void main() {
  test('equal 10 across 3 uses largest remainder in participant order', () {
    final shares = apportionTravelQuantity(
      mode: TravelApportionmentMode.equal,
      totalQty: 10,
      participantIds: const ['a', 'b', 'c'],
    );

    expect(shares, {'a': 3.3334, 'b': 3.3333, 'c': 3.3333});
  });

  test('equal shares sum to the fixed-point total', () {
    final shares = apportionTravelQuantity(
      mode: TravelApportionmentMode.equal,
      totalQty: 0.0002,
      participantIds: const ['a', 'b', 'c'],
    );

    expect(shares, {'a': 0.0001, 'b': 0.0001, 'c': 0});
  });

  test('nominated assigns the full quantity', () {
    final shares = apportionTravelQuantity(
      mode: TravelApportionmentMode.nominated,
      totalQty: 10,
      participantIds: const ['a', 'b'],
      nominatedParticipantId: 'b',
    );

    expect(shares, {'b': 10});
  });

  test('nominated rejects an inactive participant', () {
    expect(
      () => apportionTravelQuantity(
        mode: TravelApportionmentMode.nominated,
        totalQty: 10,
        participantIds: const ['a'],
        nominatedParticipantId: 'b',
      ),
      throwsArgumentError,
    );
  });
}
