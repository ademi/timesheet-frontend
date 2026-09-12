import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_travel_models.dart';
import 'package:rostiq/features/shifts/utils/travel_draft.dart';

void main() {
  const valid = TravelDraft(
    supportItemCode: '02_051_0108_1_1',
    supportItemName: 'Provider travel',
    quantity: '10',
  );

  test('valid equal draft passes all steps and creates body', () {
    expect(valid.validateAll(const ['sp-1']), isNull);
    expect(valid.toWrite().toJson(), {
      'support_item_code': '02_051_0108_1_1',
      'quantity': '10',
      'apportionment_mode': 'equal',
      'nominated_participant_id': null,
    });
  });

  test('item requires code, positive 4dp quantity, and short notes', () {
    expect(const TravelDraft(quantity: '1').validateItem(), isNotNull);
    expect(
      valid.copyWith(quantity: '0').validateItem(),
      contains('greater than 0'),
    );
    expect(
      valid.copyWith(quantity: '1.00001').validateItem(),
      contains('at most 4'),
    );
    expect(
      valid.copyWith(notes: List.filled(501, 'x').join()).validateItem(),
      contains('500'),
    );
  });

  test('nominated split requires an active nominee', () {
    final draft = valid.copyWith(
      apportionmentMode: TravelApportionmentMode.nominated,
      nominatedParticipantId: 'sp-2',
    );

    expect(draft.validateSplit(), isNull);
    expect(draft.validateReview(const ['sp-1']), contains('no longer active'));
    expect(draft.validateReview(const ['sp-1', 'sp-2']), isNull);
  });

  test('review requires active participants', () {
    expect(valid.validateReview(const []), contains('Add participants'));
  });

  test('toWrite trims and omits blank notes', () {
    final write = valid.copyWith(notes: '  ').toWrite();
    expect(write.toJson(), isNot(contains('notes')));
  });
}
