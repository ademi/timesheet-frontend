import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/utils/publish_draft.dart';

void main() {
  group('PublishDraft validation', () {
    test('default item required for step 1', () {
      expect(const PublishDraft().validateDefaultItem(), isNotNull);
      expect(
        const PublishDraft(supportItemCode: '01_011_0107_1_1')
            .validateDefaultItem(),
        isNull,
      );
    });

    test('override requires item or rate; reason when rates set', () {
      const empty = PublishParticipantOverrideDraft(participantId: 'p1');
      expect(empty.validate(), isNotNull);

      const itemOnly = PublishParticipantOverrideDraft(
        participantId: 'p1',
        supportItemCode: '01_012_0107_1_1',
      );
      expect(itemOnly.validate(), isNull);

      const rateNoReason = PublishParticipantOverrideDraft(
        participantId: 'p1',
        baseRate: 70,
      );
      expect(rateNoReason.validate(), contains('Reason'));

      const rateWithReason = PublishParticipantOverrideDraft(
        participantId: 'p1',
        baseRate: 70,
        reason: 'Negotiated',
      );
      expect(rateWithReason.validate(), isNull);
    });

    test('accommodation code and qty both required when Stay on', () {
      expect(
        const PublishDraft(accommodationEnabled: false).validateAccommodation(),
        isNull,
      );
      expect(
        const PublishDraft(accommodationEnabled: true).validateAccommodation(),
        isNotNull,
      );
      expect(
        const PublishDraft(
          accommodationEnabled: true,
          accommodationSupportItemCode: '01_058_0115_1_1',
        ).validateAccommodation(),
        contains('quantity'),
      );
      expect(
        const PublishDraft(
          accommodationEnabled: true,
          accommodationQuantity: '1',
        ).validateAccommodation(),
        contains('item'),
      );
      expect(
        const PublishDraft(
          accommodationEnabled: true,
          accommodationSupportItemCode: '01_058_0115_1_1',
          accommodationQuantity: '1',
        ).validateAccommodation(),
        isNull,
      );
      expect(
        const PublishDraft(
          accommodationEnabled: true,
          accommodationSupportItemCode: '01_058_0115_1_1',
          accommodationQuantity: '0',
        ).validateAccommodation(),
        isNotNull,
      );
    });

    test('toRequest omits stay fields when toggle off and empty overrides', () {
      final req = const PublishDraft(
        supportItemCode: '01_011_0107_1_1',
        accommodationEnabled: false,
        accommodationSupportItemCode: '01_058_0115_1_1',
        accommodationQuantity: '2',
        overrides: {
          'p1': PublishParticipantOverrideDraft(participantId: 'p1'),
        },
      ).toRequest();

      final json = req.toJson();
      expect(json['support_item_code'], '01_011_0107_1_1');
      expect(json, isNot(contains('accommodation_support_item_code')));
      expect(json, isNot(contains('participant_overrides')));
    });

    test('toRequest includes overrides and stay when set', () {
      final req = PublishDraft(
        supportItemCode: '01_011_0107_1_1',
        accommodationEnabled: true,
        accommodationSupportItemCode: '01_058_0115_1_1',
        accommodationQuantity: '2',
        overrides: const {
          'p1': PublishParticipantOverrideDraft(
            participantId: 'p1',
            supportItemCode: '01_012_0107_1_1',
            baseRate: 70,
            reason: 'High intensity',
          ),
        },
      ).toRequest();

      final json = req.toJson();
      expect(json['participant_overrides'], hasLength(1));
      expect(json['accommodation_support_item_code'], '01_058_0115_1_1');
      expect(json['accommodation_quantity'], '2');
    });

    test('validateAll aggregates step errors', () {
      expect(const PublishDraft().validateAll(), contains('default'));
      expect(
        const PublishDraft(
          supportItemCode: '01_011_0107_1_1',
          overrides: {
            'p1': PublishParticipantOverrideDraft(
              participantId: 'p1',
              baseRate: 70,
            ),
          },
        ).validateAll(),
        contains('Reason'),
      );
    });
  });
}
