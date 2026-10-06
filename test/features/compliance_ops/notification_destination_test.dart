import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/features/compliance_ops/data/models/compliance_ops_models.dart';
import 'package:rostiq/features/compliance_ops/data/models/notification_destination.dart';
import 'package:rostiq/features/compliance_ops/data/models/notification_display.dart';

NotificationEventOut _event(
  String type, {
  Map<String, dynamic> payload = const {},
  String? entityId,
}) => NotificationEventOut(
  id: '1',
  eventType: type,
  createdAt: DateTime.utc(2026, 10, 6),
  payload: payload,
  entityId: entityId,
);

void main() {
  group('resolveNotificationDestination', () {
    test('visit.assigned → contractor visit detail', () {
      final dest = resolveNotificationDestination(
        _event('visit.assigned', payload: {'visit_id': 'v1'}),
        isContractor: true,
      );
      expect(dest?.location, contains(AppRoutes.contractorVisitDetail));
      expect(dest?.location, contains('id=v1'));
    });

    test('visit.assigned → staff visit detail', () {
      final dest = resolveNotificationDestination(
        _event('visit.assigned', payload: {'visit_id': 'v1'}),
        isContractor: false,
      );
      expect(dest?.location, contains(AppRoutes.staffVisitDetail));
    });

    test('shift.slot_opened → contractor open tab only', () {
      final forContractor = resolveNotificationDestination(
        _event('shift.slot_opened', payload: {'shift_id': 's1'}),
        isContractor: true,
      );
      expect(forContractor?.location, contains(AppRoutes.contractorVisits));
      expect(forContractor?.location, contains('tab=open'));
      expect(forContractor?.location, contains('shiftId=s1'));

      expect(
        resolveNotificationDestination(
          _event('shift.slot_opened', payload: {'shift_id': 's1'}),
          isContractor: false,
        ),
        isNull,
      );
    });

    test('engagement.accepted → staff workforce detail', () {
      final dest = resolveNotificationDestination(
        _event(
          'engagement.accepted',
          payload: {'engagement_id': 'e1'},
          entityId: 'e1',
        ),
        isContractor: false,
      );
      expect(dest?.location, contains(AppRoutes.staffWorkforceDetail));
      expect(dest?.location, contains('id=e1'));
    });

    test('unknown / incomplete → null', () {
      expect(
        resolveNotificationDestination(
          _event('visit.assigned'),
          isContractor: true,
        ),
        isNull,
      );
    });
  });

  group('notificationTitle', () {
    test('maps shift.slot_opened', () {
      expect(
        notificationTitle('shift.slot_opened', {'job_title': 'Support'}),
        'Open shift available · Support',
      );
    });
  });
}
