import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/compliance_ops/data/models/compliance_ops_models.dart';
import 'package:rostiq/features/compliance_ops/data/models/notification_display.dart';

void main() {
  group('notificationTitle', () {
    test('maps visit.assigned', () {
      expect(
        notificationTitle('visit.assigned', {'job_title': 'Daily Activity'}),
        'Visit assigned · Daily Activity',
      );
    });

    test('maps engagement.invited', () {
      expect(notificationTitle('engagement.invited', {}), 'Contractor invited');
    });

    test('maps engagement.accepted', () {
      expect(notificationTitle('engagement.accepted', {}), 'Contractor accepted');
    });

    test('maps sharing.access_requested', () {
      expect(
        notificationTitle('sharing.access_requested', {}),
        'Access requested',
      );
    });

    test('unknown type title-cases', () {
      expect(notificationTitle('foo.bar_baz', {}), 'Foo bar baz');
    });
  });

  group('formatNotificationTime', () {
    test('time has no microseconds', () {
      final s = formatNotificationTime(
        DateTime.parse('2026-07-31T10:26:17.259909'),
      );
      expect(s.contains('259909'), isFalse);
    });
  });

  group('dedupeNotificationEvents', () {
    test('dedupes identical event_type+title+second', () {
      final createdAt = DateTime.parse('2026-07-31T10:26:17.259909');
      final a = NotificationEventOut(
        id: '1',
        eventType: 'visit.assigned',
        createdAt: createdAt,
        payload: const {'job_title': 'Daily Activity'},
      );
      final b = NotificationEventOut(
        id: '2',
        eventType: 'visit.assigned',
        createdAt: createdAt.add(const Duration(milliseconds: 400)),
        payload: const {'job_title': 'Daily Activity'},
      );

      final out = dedupeNotificationEvents([a, b]);

      expect(out.length, 1);
      expect(out.single.id, '1');
    });

    test('keeps rows with different job_title', () {
      final createdAt = DateTime.parse('2026-07-31T10:26:17');
      final a = NotificationEventOut(
        id: '1',
        eventType: 'visit.assigned',
        createdAt: createdAt,
        payload: const {'job_title': 'Daily Activity'},
      );
      final b = NotificationEventOut(
        id: '2',
        eventType: 'visit.assigned',
        createdAt: createdAt,
        payload: const {'job_title': 'Transport'},
      );

      expect(dedupeNotificationEvents([a, b]), hasLength(2));
    });
  });
}
