import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/utils/overnight_format.dart';

void main() {
  test('spansLocalMidnight detects +1 day', () {
    final start = DateTime(2026, 9, 20, 21);
    final end = DateTime(2026, 9, 21, 7);
    expect(spansLocalMidnight(start, end), isTrue);
    expect(spansLocalMidnight(start, DateTime(2026, 9, 20, 23)), isFalse);
  });

  test('formatOvernightRange shows +1', () {
    final start = DateTime(2026, 9, 20, 21);
    final end = DateTime(2026, 9, 21, 7);
    expect(formatOvernightRange(start, end), '21:00 → 07:00 (+1)');
  });

  test('house templates are versioned and overnight kinds', () {
    expect(kOvernightHouseTemplates, isNotEmpty);
    for (final t in kOvernightHouseTemplates) {
      expect(t.version, greaterThanOrEqualTo(1));
      expect(t.shiftKind == 'sleepover' || t.shiftKind == 'active_night', isTrue);
    }
  });

  test('active_night label differs from sleepover', () {
    expect(shiftKindLabel('sleepover'), 'Sleepover');
    expect(shiftKindLabel('active_night'), 'Active night');
    expect(shiftKindLabel('sleepover'), isNot(shiftKindLabel('active_night')));
  });
}
