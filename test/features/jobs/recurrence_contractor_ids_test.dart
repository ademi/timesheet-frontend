import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/utils/recurrence_label.dart';

RecurrenceRuleOut _rule({
  List<String> contractorIds = const [],
  List<String> contractorNames = const [],
  int requiredSlots = 1,
}) {
  return RecurrenceRuleOut(
    id: 'rule-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    contractorIds: contractorIds,
    contractorNames: contractorNames,
    requiredSlots: requiredSlots,
    rrule: 'FREQ=WEEKLY;BYDAY=MO',
    dtstart: DateTime.utc(2026, 8, 3, 9),
    timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
    isActive: true,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 1),
  );
}

void main() {
  test('recurrence create request sends contractor_ids list', () {
    final json = RecurrenceRuleCreateRequest(
      contractorIds: const ['worker-a', 'worker-b'],
      requiredSlots: 2,
      rrule: 'FREQ=WEEKLY;BYDAY=MO',
      dtstart: DateTime.utc(2026, 8, 3, 9),
      timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
    ).toJson();

    expect(json['contractor_ids'], ['worker-a', 'worker-b']);
    expect(json.containsKey('contractor_id'), isFalse);
    expect(json['required_slots'], 2);
  });

  test('ongoing support and split requests send contractor_ids list', () {
    final ongoing = OngoingSupportCreateRequest(
      clientId: 'client-1',
      title: 'Sam support',
      clientSiteId: 'site-1',
      contractorIds: const ['worker-a'],
      rrule: 'FREQ=WEEKLY;BYDAY=MO',
      dtstart: DateTime.utc(2026, 8, 3, 9),
      requiredSlots: 3,
      timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
      horizonFrom: DateTime.utc(2026, 8, 3),
      horizonTo: DateTime.utc(2026, 8, 17),
    ).toJson();
    expect(ongoing['contractor_ids'], ['worker-a']);
    expect(ongoing.containsKey('contractor_id'), isFalse);

    final split = SplitRecurrenceRequest(
      fromDate: DateTime.utc(2026, 8, 17),
      timeWindows: const [TimeWindow(startTime: '10:00', endTime: '13:00')],
      contractorIds: const ['worker-b'],
      requiredSlots: 2,
      horizonFrom: DateTime.utc(2026, 8, 17),
      horizonTo: DateTime.utc(2026, 8, 24),
    ).toJson();
    expect(split['contractor_ids'], ['worker-b']);
    expect(split.containsKey('contractor_id'), isFalse);
  });

  test('rule payload without contractor_ids parses as unfilled', () {
    final rule = RecurrenceRuleOut.fromJson({
      'id': 'rule-1',
      'tenant_id': 'tenant-1',
      'job_id': 'job-1',
      'required_slots': 2,
      'rrule': 'FREQ=WEEKLY',
      'dtstart': '2026-08-03T09:00:00Z',
      'time_windows_json': [],
      'is_active': true,
      'created_at': '2026-08-01T00:00:00Z',
      'updated_at': '2026-08-01T00:00:00Z',
    });
    expect(rule.contractorIds, isEmpty);
    expect(rule.contractorNames, isEmpty);
  });

  group('recurrenceWorkersLabel', () {
    test('unfilled rule', () {
      expect(recurrenceWorkersLabel(_rule(requiredSlots: 2)), 'Unfilled');
    });

    test('all slots pre-filled', () {
      expect(
        recurrenceWorkersLabel(
          _rule(
            contractorIds: const ['a', 'b'],
            contractorNames: const ['Jane', 'Ali'],
            requiredSlots: 2,
          ),
        ),
        'Jane, Ali',
      );
    });

    test('partially filled rule counts the open slots', () {
      expect(
        recurrenceWorkersLabel(
          _rule(
            contractorIds: const ['a'],
            contractorNames: const ['Jane'],
            requiredSlots: 3,
          ),
        ),
        'Jane · 2 open',
      );
    });
  });
}
