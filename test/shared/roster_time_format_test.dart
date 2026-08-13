import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/utils/roster_time_format.dart';

void main() {
  test('formats local window without ISO date', () {
    final start = DateTime(2026, 8, 10, 9, 0);
    expect(formatRosterStamp(start), 'Mon 10 Aug 09:00');
    expect(formatRosterStamp(start), isNot(contains('2026-08-10')));
  });
}
