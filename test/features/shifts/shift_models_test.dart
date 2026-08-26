import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';

void main() {
  test('ShiftCreateRequest.toJson omits contractor_ids and task_template when empty',
      () {
    final start = DateTime.utc(2026, 8, 22, 9);
    final end = DateTime.utc(2026, 8, 22, 12);
    final json = ShiftCreateRequest(
      jobId: 'job-1',
      scheduledStart: start,
      scheduledEnd: end,
    ).toJson();

    expect(json, isNot(contains('contractor_ids')));
    expect(json, isNot(contains('task_template')));
  });

  test('ShiftCreateRequest.toJson includes contractor_ids when set', () {
    final start = DateTime.utc(2026, 8, 22, 9);
    final end = DateTime.utc(2026, 8, 22, 12);
    final json = ShiftCreateRequest(
      jobId: 'job-1',
      scheduledStart: start,
      scheduledEnd: end,
      contractorIds: const ['c1', 'c2'],
    ).toJson();

    expect(json['contractor_ids'], ['c1', 'c2']);
    expect(json, isNot(contains('task_template')));
  });

  test('ShiftCreateRequest.toJson includes task_template when set', () {
    final start = DateTime.utc(2026, 8, 22, 9);
    final end = DateTime.utc(2026, 8, 22, 12);
    final json = ShiftCreateRequest(
      jobId: 'job-1',
      scheduledStart: start,
      scheduledEnd: end,
      contractorIds: const ['c1'],
      taskTemplate: const [
        TaskTemplateItem(title: 'Care', sortOrder: 0),
      ],
    ).toJson();

    expect(json['contractor_ids'], ['c1']);
    expect(json['task_template'], [
      {'title': 'Care', 'sort_order': 0},
    ]);
  });

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
