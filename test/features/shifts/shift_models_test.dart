import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';

void main() {
  group('ShiftOut', () {
    test('parses staff shift JSON with assignments', () {
      final shift = ShiftOut.fromJson({
        'id': 'shift-1',
        'tenant_id': 'tenant-1',
        'job_id': 'job-1',
        'job_title': 'Morning clean',
        'client_id': 'client-1',
        'client_name': 'Acme Aged Care',
        'scheduled_start': '2026-08-13T01:00:00Z',
        'scheduled_end': '2026-08-13T05:00:00Z',
        'required_slots': 2,
        'open_slots': 1,
        'status': 'published',
        'location_label': 'Site A',
        'suburb': 'Brisbane',
        'postal_code': '4000',
        'assignments': [
          {
            'id': 'a1',
            'contractor_id': 'c1',
            'contractor_name': 'Alex',
            'visit_id': 'v1',
            'source': 'staff_assign',
            'status': 'active',
          },
        ],
        'published_at': '2026-08-12T10:00:00Z',
        'created_at': '2026-08-12T09:00:00Z',
        'updated_at': '2026-08-12T10:00:00Z',
      });

      expect(shift.id, 'shift-1');
      expect(shift.requiredSlots, 2);
      expect(shift.openSlots, 1);
      expect(shift.filledSlots, 1);
      expect(shift.suburb, 'Brisbane');
      expect(shift.assignments, hasLength(1));
      expect(shift.assignments.first.contractorName, 'Alex');
    });
  });

  group('OpenShiftOut', () {
    test('parses open shift without street address', () {
      final open = OpenShiftOut.fromJson({
        'id': 'shift-2',
        'job_title': 'Evening support',
        'client_name': 'Sunrise',
        'scheduled_start': '2026-08-14T08:00:00Z',
        'scheduled_end': '2026-08-14T12:00:00Z',
        'required_slots': 2,
        'open_slots': 2,
        'suburb': 'Fortitude Valley',
        'postal_code': '4006',
      });

      expect(open.id, 'shift-2');
      expect(open.suburb, 'Fortitude Valley');
      expect(open.openSlots, 2);
    });
  });

  group('RecurrenceRuleCreateRequest', () {
    test('omits contractor_id when unassigned', () {
      final body = RecurrenceRuleCreateRequest(
        rrule: 'FREQ=WEEKLY;BYDAY=MO',
        dtstart: DateTime.utc(2026, 8, 13),
        requiredSlots: 2,
        timeWindows: const [
          TimeWindow(startTime: '09:00', endTime: '12:00'),
        ],
      ).toJson();

      expect(body.containsKey('contractor_id'), isFalse);
      expect(body['required_slots'], 2);
    });
  });
}
