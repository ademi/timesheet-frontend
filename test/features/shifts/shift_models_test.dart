import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';

void main() {
  test(
    'ShiftCreateRequest.toJson omits contractor_ids and task_template when empty',
    () {
      final start = DateTime.utc(2026, 8, 22, 9);
      final end = DateTime.utc(2026, 8, 22, 12);
      final json =
          ShiftCreateRequest(
            jobId: 'job-1',
            scheduledStart: start,
            scheduledEnd: end,
          ).toJson();

      expect(json, isNot(contains('contractor_ids')));
      expect(json, isNot(contains('task_template')));
      expect(json['worker_count'], 1);
      expect(json, isNot(contains('equal_split')));
      expect(json, isNot(contains('participants')));
    },
  );

  test('ShiftCreateRequest.toJson includes contractor_ids when set', () {
    final start = DateTime.utc(2026, 8, 22, 9);
    final end = DateTime.utc(2026, 8, 22, 12);
    final json =
        ShiftCreateRequest(
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
    final json =
        ShiftCreateRequest(
          jobId: 'job-1',
          scheduledStart: start,
          scheduledEnd: end,
          contractorIds: const ['c1'],
          taskTemplate: const [TaskTemplateItem(title: 'Care', sortOrder: 0)],
        ).toJson();

    expect(json['contractor_ids'], ['c1']);
    expect(json['task_template'], [
      {'title': 'Care', 'sort_order': 0},
    ]);
  });

  test(
    'ShiftCreateRequest.toJson includes worker_count, equal_split, participants',
    () {
      final start = DateTime.utc(2026, 8, 22, 9);
      final end = DateTime.utc(2026, 8, 22, 12);
      final json =
          ShiftCreateRequest(
            jobId: 'job-1',
            scheduledStart: start,
            scheduledEnd: end,
            workerCount: 2,
            equalSplit: true,
            participants: const [
              ShiftParticipantCreateItem(
                participantId: 'p1',
                allocationStrategy: 'percentage',
                reason: 'book',
              ),
              ShiftParticipantCreateItem(
                participantId: 'p2',
                allocationStrategy: 'percentage',
                reason: 'book',
              ),
            ],
          ).toJson();

      expect(json['worker_count'], 2);
      expect(json['equal_split'], true);
      expect(json['participants'], [
        {
          'participant_id': 'p1',
          'allocation_strategy': 'percentage',
          'reason': 'book',
        },
        {
          'participant_id': 'p2',
          'allocation_strategy': 'percentage',
          'reason': 'book',
        },
      ]);
    },
  );

  test('ShiftCreateRequest participant omits allocation_value when null', () {
    final item =
        const ShiftParticipantCreateItem(
          participantId: 'p1',
          allocationStrategy: 'percentage',
          reason: 'book',
        ).toJson();

    expect(item, isNot(contains('allocation_value')));
  });

  test('ShiftCreateRequest participant includes allocation_value when set', () {
    final item =
        const ShiftParticipantCreateItem(
          participantId: 'p1',
          allocationStrategy: 'percentage',
          allocationValue: 50,
          reason: 'book',
        ).toJson();

    expect(item['allocation_value'], 50);
  });

  test('ShiftParticipantsReplaceRequest.toJson for equal_split', () {
    final json =
        const ShiftParticipantsReplaceRequest(
          equalSplit: true,
          participants: [
            ShiftParticipantReplaceItem(participantId: 'p1'),
            ShiftParticipantReplaceItem(participantId: 'p2'),
          ],
        ).toJson();

    expect(json['equal_split'], true);
    expect(json['allocation_strategy'], 'percentage');
    expect(json['participants'], [
      {'participant_id': 'p1'},
      {'participant_id': 'p2'},
    ]);
  });

  test(
    'ShiftParticipantsReplaceRequest includes allocation_value when set',
    () {
      final json =
          const ShiftParticipantsReplaceRequest(
            equalSplit: false,
            participants: [
              ShiftParticipantReplaceItem(
                participantId: 'p1',
                allocationValue: 60,
              ),
              ShiftParticipantReplaceItem(
                participantId: 'p2',
                allocationValue: 40,
              ),
            ],
          ).toJson();

      expect(json['equal_split'], false);
      expect(json['allocation_strategy'], 'percentage');
      expect(json['participants'][0]['allocation_value'], 60);
      expect(json['participants'][1]['allocation_value'], 40);
    },
  );

  test('ShiftParticipantsReplaceRequest time_based includes time_windows', () {
    final start = DateTime.utc(2026, 9, 12, 10);
    final mid = DateTime.utc(2026, 9, 12, 12);
    final end = DateTime.utc(2026, 9, 12, 14);
    final json =
        ShiftParticipantsReplaceRequest(
          allocationStrategy: 'time_based',
          equalSplit: false,
          participants: [
            ShiftParticipantReplaceItem(
              participantId: 'p1',
              allocationValue: 0,
              timeWindows: [
                ShiftParticipantTimeWindowInput(
                  participantStartTime: start,
                  participantEndTime: mid,
                ),
                ShiftParticipantTimeWindowInput(
                  participantStartTime: mid.add(const Duration(minutes: 30)),
                  participantEndTime: end,
                ),
              ],
            ),
          ],
        ).toJson();

    expect(json['allocation_strategy'], 'time_based');
    expect(json['equal_split'], false);
    expect(json['participants'][0]['allocation_value'], 0);
    expect(json['participants'][0]['time_windows'], [
      {
        'participant_start_time': '2026-09-12T10:00:00.000Z',
        'participant_end_time': '2026-09-12T12:00:00.000Z',
      },
      {
        'participant_start_time': '2026-09-12T12:30:00.000Z',
        'participant_end_time': '2026-09-12T14:00:00.000Z',
      },
    ]);
  });

  test('ShiftParticipantCreateItem includes time_windows when set', () {
    final start = DateTime.utc(2026, 9, 12, 10);
    final end = DateTime.utc(2026, 9, 12, 14);
    final item =
        ShiftParticipantCreateItem(
          participantId: 'p1',
          allocationStrategy: 'time_based',
          allocationValue: 0,
          reason: 'group_shift_book',
          timeWindows: [
            ShiftParticipantTimeWindowInput(
              participantStartTime: start,
              participantEndTime: end,
            ),
          ],
        ).toJson();

    expect(item['allocation_strategy'], 'time_based');
    expect(item['allocation_value'], 0);
    expect(item['time_windows'], [
      {
        'participant_start_time': '2026-09-12T10:00:00.000Z',
        'participant_end_time': '2026-09-12T14:00:00.000Z',
      },
    ]);
  });

  test('ShiftPublishRequest.toJson omits empty support_item_code', () {
    expect(const ShiftPublishRequest().toJson(), isEmpty);
    expect(
      const ShiftPublishRequest(supportItemCode: '01_011_0107_1_1').toJson(),
      {'support_item_code': '01_011_0107_1_1'},
    );
  });

  test('ShiftParticipantPublishOverride.toJson includes rates and reason', () {
    expect(
      const ShiftParticipantPublishOverride(
        participantId: 'p1',
        supportItemCode: '01_012_0107_1_1',
        baseRate: 70.5,
        saturdayRate: 80,
        reason: 'High intensity',
      ).toJson(),
      {
        'participant_id': 'p1',
        'support_item_code': '01_012_0107_1_1',
        'base_rate': 70.5,
        'saturday_rate': 80,
        'reason': 'High intensity',
      },
    );
  });

  test('ShiftPublishRequest.toJson includes overrides and accommodation', () {
    final json =
        ShiftPublishRequest(
          supportItemCode: '01_011_0107_1_1',
          participantOverrides: const [
            ShiftParticipantPublishOverride(
              participantId: 'p1',
              supportItemCode: '01_012_0107_1_1',
              reason: 'High intensity',
            ),
          ],
          accommodationSupportItemCode: '01_058_0115_1_1',
          accommodationQuantity: '2',
        ).toJson();

    expect(json['support_item_code'], '01_011_0107_1_1');
    expect(json['participant_overrides'], [
      {
        'participant_id': 'p1',
        'support_item_code': '01_012_0107_1_1',
        'reason': 'High intensity',
      },
    ]);
    expect(json['accommodation_support_item_code'], '01_058_0115_1_1');
    expect(json['accommodation_quantity'], '2');
  });

  test(
    'ShiftPublishRequest.toJson omits empty overrides and accommodation',
    () {
      expect(
        const ShiftPublishRequest(
          supportItemCode: '01_011_0107_1_1',
          participantOverrides: [],
        ).toJson(),
        {'support_item_code': '01_011_0107_1_1'},
      );
    },
  );

  test('ShiftPatchRequest.toJson sends worker_count', () {
    expect(const ShiftPatchRequest(workerCount: 3).toJson(), {
      'worker_count': 3,
    });
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

  test('ShiftOut parses worker_count, warnings, and full participants', () {
    final shift = ShiftOut.fromJson({
      'id': 'shift-1',
      'tenant_id': 'tenant-1',
      'job_id': 'job-1',
      'job_title': 'Group support',
      'scheduled_start': '2026-08-22T09:00:00Z',
      'scheduled_end': '2026-08-22T12:00:00Z',
      'required_slots': 2,
      'open_slots': 1,
      'worker_count': 2,
      'status': 'draft',
      'warnings': ['worker_count_slots_mismatch'],
      'participants': [
        {
          'id': 'sp-1',
          'shift_id': 'shift-1',
          'participant_id': 'client-1',
          'allocation_strategy': 'percentage',
          'allocation_value': 50.0,
          'status': 'active',
          'participant_name': 'Alex',
          'rate_snapshot': {
            'support_item_code': '01_011_0107_1_1',
            'base_rate': 62.17,
            'price_limit_national': 65.0,
            'rate_override_reason': null,
          },
          'time_windows': [
            {
              'id': 'tw-1',
              'shift_participant_id': 'sp-1',
              'participant_start_time': '2026-08-22T09:00:00Z',
              'participant_end_time': '2026-08-22T10:30:00Z',
              'created_at': '2026-08-22T08:00:00Z',
            },
          ],
          'created_at': '2026-08-22T08:00:00Z',
          'updated_at': '2026-08-22T08:05:00Z',
        },
      ],
      'assignments': [],
      'created_at': '2026-08-22T08:00:00Z',
      'updated_at': '2026-08-22T08:05:00Z',
    });

    expect(shift.workerCount, 2);
    expect(shift.warnings, ['worker_count_slots_mismatch']);
    expect(shift.participants, hasLength(1));
    final p = shift.participants.single;
    expect(p.id, 'sp-1');
    expect(p.shiftId, 'shift-1');
    expect(p.participantId, 'client-1');
    expect(p.allocationStrategy, 'percentage');
    expect(p.allocationValue, 50.0);
    expect(p.status, 'active');
    expect(p.participantName, 'Alex');
    expect(p.rateSnapshot?.supportItemCode, '01_011_0107_1_1');
    expect(p.rateSnapshot?.baseRate, 62.17);
    expect(p.timeWindows, hasLength(1));
    expect(p.timeWindows!.single.id, 'tw-1');
  });

  test('ShiftOut parses accommodation fields', () {
    final shift = ShiftOut.fromJson({
      'id': 'shift-1',
      'tenant_id': 'tenant-1',
      'job_id': 'job-1',
      'job_title': 'Group support',
      'scheduled_start': '2026-08-22T09:00:00Z',
      'scheduled_end': '2026-08-22T12:00:00Z',
      'required_slots': 1,
      'open_slots': 1,
      'worker_count': 1,
      'status': 'published',
      'accommodation_support_item_code': '01_058_0115_1_1',
      'accommodation_quantity': 2,
      'participants': [],
      'assignments': [],
      'created_at': '2026-08-22T08:00:00Z',
      'updated_at': '2026-08-22T08:05:00Z',
    });

    expect(shift.accommodationSupportItemCode, '01_058_0115_1_1');
    expect(shift.accommodationQuantity, '2');
  });

  test('ShiftOut parses list participants_summary shape', () {
    final shift = ShiftOut.fromJson({
      'id': 'shift-1',
      'tenant_id': 'tenant-1',
      'job_id': 'job-1',
      'job_title': 'Group support',
      'scheduled_start': '2026-08-22T09:00:00Z',
      'scheduled_end': '2026-08-22T12:00:00Z',
      'required_slots': 1,
      'open_slots': 1,
      'worker_count': 1,
      'status': 'draft',
      'participants': [
        {
          'id': 'sp-1',
          'participant_id': 'client-1',
          'participant_name': 'Alex',
          'status': 'active',
        },
      ],
      'assignments': [],
      'created_at': '2026-08-22T08:00:00Z',
      'updated_at': '2026-08-22T08:05:00Z',
    });

    expect(shift.participants, hasLength(1));
    final p = shift.participants.single;
    expect(p.id, 'sp-1');
    expect(p.participantId, 'client-1');
    expect(p.participantName, 'Alex');
    expect(p.status, 'active');
    expect(p.shiftId, isNull);
    expect(p.allocationStrategy, isNull);
    expect(p.allocationValue, isNull);
  });

  test('ShiftOut defaults worker_count and warnings when absent', () {
    final shift = ShiftOut.fromJson({
      'id': 'shift-1',
      'tenant_id': 'tenant-1',
      'job_id': 'job-1',
      'job_title': 'Support',
      'scheduled_start': '2026-08-22T09:00:00Z',
      'scheduled_end': '2026-08-22T12:00:00Z',
      'required_slots': 1,
      'open_slots': 1,
      'status': 'draft',
      'assignments': [],
      'created_at': '2026-08-22T08:00:00Z',
      'updated_at': '2026-08-22T08:05:00Z',
    });

    expect(shift.workerCount, 1);
    expect(shift.warnings, isEmpty);
    expect(shift.participants, isEmpty);
    expect(shift.travelClaims, isEmpty);
  });

  test('ShiftOut parses embedded travel claims', () {
    final shift = ShiftOut.fromJson({
      'id': 'shift-1',
      'tenant_id': 'tenant-1',
      'job_id': 'job-1',
      'job_title': 'Support',
      'scheduled_start': '2026-08-22T09:00:00Z',
      'scheduled_end': '2026-08-22T12:00:00Z',
      'required_slots': 1,
      'open_slots': 1,
      'status': 'draft',
      'assignments': [],
      'travel_claims': [
        {
          'id': 'travel-1',
          'shift_id': 'shift-1',
          'support_item_code': '02_051_0108_1_1',
          'quantity': '10',
          'apportionment_mode': 'equal',
          'nominated_participant_id': null,
          'claimed_export_id': null,
          'notes': 'Return trip',
          'created_at': '2026-09-12T00:00:00Z',
          'updated_at': '2026-09-12T00:00:00Z',
        },
      ],
      'created_at': '2026-08-22T08:00:00Z',
      'updated_at': '2026-08-22T08:05:00Z',
    });

    expect(shift.travelClaims, hasLength(1));
    expect(shift.travelClaims.single.notes, 'Return trip');
  });

  test('AllocationChangeLogOut.fromJson parses audit entry', () {
    final entry = AllocationChangeLogOut.fromJson({
      'id': 'log-1',
      'shift_id': 'shift-1',
      'change_type': 'participant_removed',
      'participant_id': 'client-1',
      'old_allocation_value': 50.0,
      'new_allocation_value': null,
      'old_allocation_strategy': 'percentage',
      'new_allocation_strategy': null,
      'change_reason': 'Left early',
      'changed_by_user_id': 'user-1',
      'created_at': '2026-08-22T10:00:00Z',
    });

    expect(entry.id, 'log-1');
    expect(entry.shiftId, 'shift-1');
    expect(entry.changeType, 'participant_removed');
    expect(entry.participantId, 'client-1');
    expect(entry.oldAllocationValue, 50.0);
    expect(entry.newAllocationValue, isNull);
    expect(entry.changeReason, 'Left early');
    expect(entry.changedByUserId, 'user-1');
  });
}
