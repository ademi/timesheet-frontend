import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/utils/allocation_math.dart';

void main() {
  group('equalPercentageValues', () {
    test('n=1 is 100', () {
      expect(equalPercentageValues(1), [100.0]);
    });

    test('n=2 splits evenly', () {
      expect(equalPercentageValues(2), [50.0, 50.0]);
      expect(sumValues(equalPercentageValues(2)), 100.0);
    });

    test('n=3 uses largest remainder in hundredths', () {
      expect(equalPercentageValues(3), [33.34, 33.33, 33.33]);
      expect(sumValues(equalPercentageValues(3)), 100.0);
    });

    test('n=5 splits evenly', () {
      expect(equalPercentageValues(5), [20.0, 20.0, 20.0, 20.0, 20.0]);
      expect(sumValues(equalPercentageValues(5)), 100.0);
    });

    test('rejects n < 1', () {
      expect(() => equalPercentageValues(0), throwsArgumentError);
      expect(() => equalPercentageValues(-1), throwsArgumentError);
    });
  });

  group('sum / remaining / sumsTo100', () {
    test('sumValues totals allocations', () {
      expect(sumValues([60.0, 40.0]), 100.0);
      expect(sumValues(const <double>[]), 0.0);
    });

    test('remainingTo100 is positive when under', () {
      expect(remainingTo100([40.0, 40.0]), 20.0);
    });

    test('remainingTo100 is negative when over', () {
      expect(remainingTo100([60.0, 50.0]), -10.0);
    });

    test('sumsTo100 respects epsilon', () {
      expect(sumsTo100([33.34, 33.33, 33.33]), isTrue);
      expect(sumsTo100([50.0, 49.995]), isTrue);
      expect(sumsTo100([50.0, 49.98]), isFalse);
      expect(sumsTo100([60.0, 40.0]), isTrue);
      expect(sumsTo100([60.0, 39.0]), isFalse);
    });
  });

  group('looksEqualSplit', () {
    test('true for equalPercentageValues', () {
      expect(looksEqualSplit(equalPercentageValues(2)), isTrue);
      expect(looksEqualSplit(equalPercentageValues(3)), isTrue);
    });

    test('false for custom split that still sums to 100', () {
      expect(sumsTo100([60.0, 40.0]), isTrue);
      expect(looksEqualSplit([60.0, 40.0]), isFalse);
    });

    test('empty is equal', () {
      expect(looksEqualSplit(const <double>[]), isTrue);
    });
  });

  group('large group gates', () {
    test('needsLargeGroupConfirm at N >= 9', () {
      expect(needsLargeGroupConfirm(8), isFalse);
      expect(needsLargeGroupConfirm(9), isTrue);
      expect(needsLargeGroupConfirm(10), isTrue);
    });

    test('atHardCap at N >= 32', () {
      expect(atHardCap(31), isFalse);
      expect(atHardCap(32), isTrue);
      expect(atHardCap(33), isTrue);
    });
  });

  group('remainingCapacityLabel', () {
    test('shows remaining when under 100', () {
      expect(remainingCapacityLabel([40.0, 40.0]), 'Remaining: 20%');
    });

    test('shows over when above 100', () {
      expect(remainingCapacityLabel([60.0, 50.0]), 'Over by 10%');
    });

    test('shows zero remaining at 100', () {
      expect(remainingCapacityLabel([50.0, 50.0]), 'Remaining: 0%');
    });
  });
}
