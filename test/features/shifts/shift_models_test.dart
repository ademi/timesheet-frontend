import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';

void main() {
  test('parses engagement_id on shift assignment', () {
    final assignment = ShiftAssignmentOut.fromJson({
      'id': 'assignment-1',
      'contractor_id': 'contractor-1',
      'contractor_name': 'Jane',
      'visit_id': 'visit-1',
      'source': 'staff_assign',
      'status': 'active',
      'visit_status': 'scheduled',
      'engagement_id': 'engagement-1',
    });

    expect(assignment.engagementId, 'engagement-1');
  });
}
