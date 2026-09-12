import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/utils/publish_draft.dart';
import 'package:rostiq/features/shifts/utils/publish_estimate_math.dart';

void main() {
  group('mode detection', () {
    test('equal 50/50 → ndis_group', () {
      expect(
        detectPricingMode(const [
          PublishAllocationRow(
            participantId: 'a',
            strategy: 'percentage',
            value: 50,
          ),
          PublishAllocationRow(
            participantId: 'b',
            strategy: 'percentage',
            value: 50,
          ),
        ]),
        PublishPricingMode.ndisGroup,
      );
    });

    test('lone 100% → ndis_group; lone 40% → allocated_share', () {
      expect(
        detectPricingMode(const [
          PublishAllocationRow(
            participantId: 'a',
            strategy: 'percentage',
            value: 100,
          ),
        ]),
        PublishPricingMode.ndisGroup,
      );
      expect(
        detectPricingMode(const [
          PublishAllocationRow(
            participantId: 'a',
            strategy: 'percentage',
            value: 40,
          ),
        ]),
        PublishPricingMode.allocatedShare,
      );
    });

    test('60/40 and time_based → allocated_share', () {
      expect(
        detectPricingMode(const [
          PublishAllocationRow(
            participantId: 'a',
            strategy: 'percentage',
            value: 60,
          ),
          PublishAllocationRow(
            participantId: 'b',
            strategy: 'percentage',
            value: 40,
          ),
        ]),
        PublishPricingMode.allocatedShare,
      );
      expect(
        detectPricingMode(const [
          PublishAllocationRow(
            participantId: 'a',
            strategy: 'time_based',
            value: 0,
          ),
          PublishAllocationRow(
            participantId: 'b',
            strategy: 'time_based',
            value: 0,
          ),
        ]),
        PublishPricingMode.allocatedShare,
      );
    });

    test('33.34/33.33/33.33 is equal', () {
      expect(
        isEqualPercentageShare(const [
          PublishAllocationRow(
            participantId: 'a',
            strategy: 'percentage',
            value: 33.34,
          ),
          PublishAllocationRow(
            participantId: 'b',
            strategy: 'percentage',
            value: 33.33,
          ),
          PublishAllocationRow(
            participantId: 'c',
            strategy: 'percentage',
            value: 33.33,
          ),
        ]),
        isTrue,
      );
    });
  });

  group('priceParticipantLine', () {
    test('ndis_group: P=67.56 N=2 visit=180 → qty 3 unit 33.78 amount 101.34', () {
      final line = priceParticipantLine(
        mode: PublishPricingMode.ndisGroup,
        tierUnitPrice: 67.56,
        groupSize: 2,
        visitMinutes: 180,
        allocatedMinutes: 180,
      );
      expect(line.quantity, 3.0);
      expect(line.unitPrice, 33.78);
      expect(line.amount, 101.34);
    });

    test(
      'allocated_share: P=67.56 allocated=108 → qty 1.8 unit 67.56 amount 121.61',
      () {
        final line = priceParticipantLine(
          mode: PublishPricingMode.allocatedShare,
          tierUnitPrice: 67.56,
          groupSize: 2,
          visitMinutes: 180,
          allocatedMinutes: 108,
        );
        expect(line.quantity, 1.8);
        expect(line.unitPrice, 67.56);
        expect(line.amount, 121.61);
      },
    );
  });

  group('allocatePercentageMinutes', () {
    test('60/40 of 480 → 288 / 192', () {
      final map = allocatePercentageMinutes(
        allocations: const [
          PublishAllocationRow(
            participantId: 'a',
            strategy: 'percentage',
            value: 60,
          ),
          PublishAllocationRow(
            participantId: 'b',
            strategy: 'percentage',
            value: 40,
          ),
        ],
        shiftMinutes: 480,
      );
      expect(map['a'], 288);
      expect(map['b'], 192);
    });

    test('33.33/33.33/33.34 of 10 → 3/3/4', () {
      final map = allocatePercentageMinutes(
        allocations: const [
          PublishAllocationRow(
            participantId: 'a',
            strategy: 'percentage',
            value: 33.33,
          ),
          PublishAllocationRow(
            participantId: 'b',
            strategy: 'percentage',
            value: 33.33,
          ),
          PublishAllocationRow(
            participantId: 'c',
            strategy: 'percentage',
            value: 33.34,
          ),
        ],
        shiftMinutes: 10,
      );
      expect(map['a'], 3);
      expect(map['b'], 3);
      expect(map['c'], 4);
    });
  });

  group('estimatePublishClaims hybrid', () {
    final start = DateTime.utc(2026, 9, 12, 9);
    final end = start.add(const Duration(hours: 3));

    ShiftParticipantOut p({
      required String id,
      required double pct,
      String strategy = 'percentage',
      List<ShiftParticipantAllocationOut>? windows,
    }) {
      return ShiftParticipantOut(
        id: 'sp-$id',
        participantId: id,
        participantName: id,
        status: 'active',
        allocationStrategy: strategy,
        allocationValue: pct,
        timeWindows: windows,
      );
    }

    test('equal share uses hours × (P/N); base_rate overrides P', () {
      final estimates = estimatePublishClaims(
        activeParticipants: [
          p(id: 'a', pct: 50),
          p(id: 'b', pct: 50),
        ],
        scheduledStart: start,
        scheduledEnd: end,
        draft: const PublishDraft(
          supportItemCode: '01_011_0107_1_1',
          overrides: {
            'b': PublishParticipantOverrideDraft(
              participantId: 'b',
              baseRate: 80,
              reason: 'Negotiated',
            ),
          },
        ),
        catalogueNationalByCode: const {'01_011_0107_1_1': 67.56},
      );

      expect(estimates, hasLength(2));
      // hours=3, P/N for a: 67.56/2=33.78 → 101.34
      expect(estimates[0].supportAmount, 101.34);
      // b uses base_rate 80 / 2 = 40 → 120.00
      expect(estimates[1].supportAmount, 120.0);
      expect(estimates[0].pricingMode, PublishPricingMode.ndisGroup);
    });

    test('unequal 60/40 uses allocatedHours × P', () {
      final estimates = estimatePublishClaims(
        activeParticipants: [
          p(id: 'a', pct: 60),
          p(id: 'b', pct: 40),
        ],
        scheduledStart: start,
        scheduledEnd: start.add(const Duration(hours: 2)),
        draft: const PublishDraft(supportItemCode: '01_011_0107_1_1'),
        catalogueNationalByCode: const {'01_011_0107_1_1': 50},
      );

      // 120 min visit → 72 / 48 mins → 1.2 / 0.8 hours × 50
      expect(estimates[0].supportAmount, 60.0);
      expect(estimates[1].supportAmount, 40.0);
      expect(estimates[0].pricingMode, PublishPricingMode.allocatedShare);
    });

    test('accommodation adds full day price per participant (not ÷N)', () {
      final estimates = estimatePublishClaims(
        activeParticipants: [
          p(id: 'a', pct: 50),
          p(id: 'b', pct: 50),
        ],
        scheduledStart: start,
        scheduledEnd: end,
        draft: const PublishDraft(
          supportItemCode: '01_011_0107_1_1',
          accommodationEnabled: true,
          accommodationSupportItemCode: '01_058_0115_1_1',
          accommodationQuantity: '1',
        ),
        catalogueNationalByCode: const {
          '01_011_0107_1_1': 67.56,
          '01_058_0115_1_1': 162.85,
        },
      );

      expect(estimates[0].accommodationAmount, 162.85);
      expect(estimates[1].accommodationAmount, 162.85);
      expect(estimates[0].total, closeTo(101.34 + 162.85, 0.001));
    });
  });
}
