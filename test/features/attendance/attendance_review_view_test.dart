import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/attendance/data/attendance_review_models.dart';
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

  test('attendanceExceptionHeadline labels B5 variance kinds', () {
    expect(
      attendanceExceptionHeadline('geofence_outside', 'geofence_outside'),
      'Clock-in outside geofence',
    );
    expect(
      attendanceExceptionHeadline(
        'geofence_outside',
        'geofence_outside_clock_out',
      ),
      'Clock-out outside geofence',
    );
    expect(
      attendanceExceptionHeadline('early_clock_out', 'early_clock_out'),
      'Early clock-out',
    );
  });
}
