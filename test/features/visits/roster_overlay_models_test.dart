import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';

void main() {
  group('RosterOverlayOut', () {
    test('parses leave', () {
      final o = RosterOverlayOut.fromJson({
        'contractors': [
          {
            'contractor_id': 'c1',
            'display_name': 'Jane',
            'leave': [
              {
                'start_date': '2026-08-13',
                'end_date': '2026-08-13',
                'leave_type': 'sick',
              },
            ],
            'availability': [
              {
                'day_of_week': 0,
                'start_time': '09:00:00',
                'end_time': '17:00:00',
              },
            ],
          },
        ],
        'truncated': false,
      });
      expect(o.contractors.first.leave.first.leaveType, 'sick');
    });
  });
}
