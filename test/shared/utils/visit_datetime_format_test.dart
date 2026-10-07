import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/utils/visit_datetime_format.dart';

void main() {
  test('formatVisitDate includes slash date and weekday abbr', () {
    // Saturday 2026-10-03 (local, ignore timezone by using DateTime local ctor).
    final sat = DateTime(2026, 10, 3, 10, 12);
    expect(formatVisitDate(sat), '2026/10/03 Sat');
  });

  test('formatVisitDateTime appends HH:mm', () {
    final sat = DateTime(2026, 10, 3, 10, 12);
    expect(formatVisitDateTime(sat), '2026/10/03 Sat 10:12');
  });

  test('formatVisitDateTimeRange joins with en dash', () {
    final start = DateTime(2026, 10, 3, 10, 12);
    final end = DateTime(2026, 10, 3, 12, 12);
    expect(
      formatVisitDateTimeRange(start, end),
      '2026/10/03 Sat 10:12 – 2026/10/03 Sat 12:12',
    );
  });

  test('weekday abbr covers Mon–Sun', () {
    expect(formatVisitDate(DateTime(2026, 10, 5)), endsWith(' Mon')); // Mon
    expect(formatVisitDate(DateTime(2026, 10, 6)), endsWith(' Tue'));
    expect(formatVisitDate(DateTime(2026, 10, 7)), endsWith(' Wed'));
    expect(formatVisitDate(DateTime(2026, 10, 8)), endsWith(' Thu'));
    expect(formatVisitDate(DateTime(2026, 10, 9)), endsWith(' Fri'));
    expect(formatVisitDate(DateTime(2026, 10, 10)), endsWith(' Sat'));
    expect(formatVisitDate(DateTime(2026, 10, 11)), endsWith(' Sun'));
  });
}
