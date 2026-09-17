import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/attendance/views/attendance_review_view.dart';

void main() {
  test('attendanceVisitSubtitleRef shortens long UUIDs', () {
    expect(
      attendanceVisitSubtitleRef('abcdef12-3456-7890-abcd-ef1234567890'),
      'abcdef12',
    );
  });

  test('attendanceVisitSubtitleRef keeps short ids', () {
    expect(attendanceVisitSubtitleRef('visit-1'), 'visit-1');
  });

  test('attendanceVisitSubtitleRef omits blank', () {
    expect(attendanceVisitSubtitleRef('  '), '');
  });
}
