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
      attendanceExceptionHeadline(
        'geofence_outside',
        'geofence_outside',
        punchKind: 'clock_out',
      ),
      'Clock-out outside geofence',
    );
    expect(
      attendanceExceptionHeadline('early_clock_out', 'early_clock_out'),
      'Early clock-out',
    );
  });

  test('formatGeofenceDistanceKm formats meters and kilometers', () {
    expect(formatGeofenceDistanceKm(250), '250 m outside');
    expect(formatGeofenceDistanceKm(1250), '1.3 km outside');
    expect(formatGeofenceDistanceKm(12505312), '12505 km outside');
    expect(formatGeofenceDistanceKm(null), isNull);
  });

  test('AttendanceExceptionOut.fromJson reads visit_context and geofence', () {
    final parsed = AttendanceExceptionOut.fromJson({
      'id': 'ex-1',
      'tenant_id': 't1',
      'visit_id': 'v1',
      'time_entry_id': 'te-1',
      'kind': 'geofence_outside',
      'reason_code': 'geofence_outside',
      'status': 'pending_ack',
      'opened_at': '2026-10-14T09:03:10.003791Z',
      'visit_context': {
        'visit_id': 'v1',
        'contractor_id': 'c1',
        'contractor_name': 'Jane Rivera',
        'client_id': 'cl1',
        'client_name': 'Casey Client',
        'location_label': '42 Harbour Rd, Sydney, NSW, 2000, AU',
        'scheduled_start': '2026-10-14T09:00:00Z',
        'scheduled_end': '2026-10-14T11:00:00Z',
      },
      'geofence': {
        'distance_m': 1250.0,
        'radius_m': 100,
        'punch_lat': 15.31,
        'punch_lng': 44.18,
        'site_lat': -33.8568,
        'site_lng': 151.2153,
        'nearest_stop_label': 'Home',
        'punch_kind': 'clock_in',
        'punch_at': '2026-10-14T09:03:10Z',
      },
    });

    expect(parsed.visitContext?.contractorName, 'Jane Rivera');
    expect(parsed.visitContext?.clientName, 'Casey Client');
    expect(
      parsed.visitContext?.locationLabel,
      '42 Harbour Rd, Sydney, NSW, 2000, AU',
    );
    expect(parsed.geofence?.distanceM, 1250.0);
    expect(parsed.geofence?.distanceLabel, '1.3 km outside');
    expect(parsed.geofence?.punchKind, 'clock_in');

    final item = AttendanceReviewItem.fromException(parsed);
    expect(item.headline, 'Clock-in outside geofence');
    expect(item.visitContext?.contractorName, 'Jane Rivera');
    expect(item.geofence?.distanceLabel, '1.3 km outside');
  });
}
