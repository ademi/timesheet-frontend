import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';

void main() {
  test('manual visit serializes required forms from the job catalog', () {
    final request = ManualVisitCreateRequest(
      contractorId: 'contractor-1',
      scheduledStart: DateTime.utc(2026, 7, 30, 9),
      scheduledEnd: DateTime.utc(2026, 7, 30, 10),
      formTemplateIds: const ['form-1', 'form-2'],
    );

    expect(request.toJson()['form_requirements'], [
      {'form_template_id': 'form-1', 'is_required': true},
      {'form_template_id': 'form-2', 'is_required': true},
    ]);
  });

  test('parses human display names for job and recurrence records', () {
    final job = JobOut.fromJson({
      'id': 'job-1',
      'tenant_id': 'tenant-1',
      'kind': 'standing',
      'status': 'open',
      'title': 'Morning support',
      'client_site_id': 'site-1',
      'client_site_name': 'North Clinic',
      'client_name': 'Acme Care',
      'location_label': '123 Example Street, Sydney, NSW, 2000, Australia',
      'geofence_radius_m': 100,
      'geofence_mode': 'informational',
      'created_at': '2026-07-30T09:00:00Z',
      'updated_at': '2026-07-30T09:00:00Z',
    });
    final rule = RecurrenceRuleOut.fromJson({
      'id': 'rule-1',
      'tenant_id': 'tenant-1',
      'job_id': 'job-1',
      'contractor_id': 'contractor-1',
      'contractor_name': 'Sam Worker',
      'rrule': 'FREQ=WEEKLY',
      'dtstart': '2026-07-30T09:00:00Z',
      'time_windows_json': [],
      'is_active': true,
      'created_at': '2026-07-30T09:00:00Z',
      'updated_at': '2026-07-30T09:00:00Z',
    });

    expect(job.clientSiteName, 'North Clinic');
    expect(job.clientName, 'Acme Care');
    expect(
      job.locationLabel,
      '123 Example Street, Sydney, NSW, 2000, Australia',
    );
    expect(rule.contractorName, 'Sam Worker');
  });

  test('parses horizon and ongoing-support payloads', () {
    final horizon = HorizonOut.fromJson({
      'created_shift_ids': ['s1'],
      'created_visit_ids': <String>[],
      'skipped': [
        {'scheduled_start': '2026-08-10T09:00:00Z', 'detail': 'visit_overlap'},
      ],
      'rules_processed': 1,
      'truncated': false,
    });
    expect(horizon.createdShiftIds, ['s1']);
    expect(horizon.skipped.first.detail, 'visit_overlap');

    final ongoing = OngoingSupportOut.fromJson({
      'job': {
        'id': 'job-1',
        'tenant_id': 'tenant-1',
        'kind': 'standing',
        'status': 'open',
        'title': 'Morning support',
        'geofence_radius_m': 100,
        'geofence_mode': 'informational',
        'created_at': '2026-07-30T09:00:00Z',
        'updated_at': '2026-07-30T09:00:00Z',
      },
      'rule': {
        'id': 'rule-1',
        'tenant_id': 'tenant-1',
        'job_id': 'job-1',
        'rrule': 'FREQ=WEEKLY',
        'dtstart': '2026-07-30T09:00:00Z',
        'time_windows_json': [
          {'start_time': '09:00', 'end_time': '12:00'},
        ],
        'is_active': true,
        'created_at': '2026-07-30T09:00:00Z',
        'updated_at': '2026-07-30T09:00:00Z',
      },
      'horizon': {
        'created_shift_ids': ['s1'],
        'created_visit_ids': <String>[],
        'skipped': <Map<String, dynamic>>[],
        'rules_processed': 1,
        'truncated': false,
      },
    });
    expect(ongoing.job.id, 'job-1');
    expect(ongoing.rule.id, 'rule-1');
    expect(ongoing.horizon.createdShiftIds, ['s1']);
  });

  test('serializes horizon and ongoing-support requests', () {
    final horizonReq = HorizonRequest(
      from: DateTime.utc(2026, 8, 3),
      to: DateTime.utc(2026, 8, 17),
      ruleIds: const ['rule-1'],
    );
    expect(horizonReq.toJson(), {
      'from': '2026-08-03T00:00:00.000Z',
      'to': '2026-08-17T00:00:00.000Z',
      'rule_ids': ['rule-1'],
    });

    final ongoingReq = OngoingSupportCreateRequest(
      clientId: 'client-1',
      title: 'Morning support',
      clientSiteId: 'site-1',
      rrule: 'FREQ=WEEKLY',
      dtstart: DateTime.utc(2026, 7, 30, 9),
      timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
      horizonFrom: DateTime.utc(2026, 8, 3),
      horizonTo: DateTime.utc(2026, 8, 17),
    );
    final json = ongoingReq.toJson();
    expect(json['client_id'], 'client-1');
    expect(json['client_site_id'], 'site-1');
    expect(json['branch_id'], isNull);
    expect(json['time_windows'], [
      {'start_time': '09:00', 'end_time': '12:00'},
    ]);
  });

  test('parses a visit location label from the API', () {
    final visit = VisitOut.fromJson({
      'id': 'visit-1',
      'tenant_id': 'tenant-1',
      'job_id': 'job-1',
      'contractor_id': 'contractor-1',
      'engagement_id': 'engagement-1',
      'shift_id': 'shift-1',
      'scheduled_start': '2026-07-30T09:00:00Z',
      'scheduled_end': '2026-07-30T10:00:00Z',
      'status': 'scheduled',
      'source': 'manual',
      'location_label': '123 Example Street, Sydney, NSW, 2000, Australia',
      'support_item_code': '01_011_0107_1_1',
      'support_item_name': 'Self care',
      'price_tier_override': 'remote',
      'geofence_radius_m': 100,
      'geofence_mode': 'informational',
      'payment_status': 'unpaid',
      'tasks': [
        {
          'id': 'task-1',
          'tenant_id': 'tenant-1',
          'visit_id': 'visit-1',
          'title': 'Shower',
          'sort_order': 0,
          'is_done': false,
          'support_item_code': '01_011_0107_1_1',
          'billable_minutes': 45,
        },
      ],
      'created_at': '2026-07-30T09:00:00Z',
      'updated_at': '2026-07-30T09:00:00Z',
    });

    expect(
      visit.locationLabel,
      '123 Example Street, Sydney, NSW, 2000, Australia',
    );
    expect(visit.engagementId, 'engagement-1');
    expect(visit.shiftId, 'shift-1');
    expect(visit.supportItemCode, '01_011_0107_1_1');
    expect(visit.priceTierOverride, 'remote');
    expect(visit.tasks.single.billableMinutes, 45);
  });

  test('parses job support item fields and task template items', () {
    final job = JobOut.fromJson({
      'id': 'job-1',
      'tenant_id': 'tenant-1',
      'kind': 'standing',
      'status': 'open',
      'title': 'Morning support',
      'support_item_code': '01_011_0107_1_1',
      'support_item_name': 'Self care',
      'geofence_radius_m': 100,
      'geofence_mode': 'informational',
      'created_at': '2026-07-30T09:00:00Z',
      'updated_at': '2026-07-30T09:00:00Z',
    });
    expect(job.supportItemCode, '01_011_0107_1_1');

    final template = TaskTemplateItem.fromJson({
      'title': 'Shower',
      'sort_order': 1,
      'support_item_code': '01_011_0107_1_1',
    });
    expect(template.toJson()['support_item_code'], '01_011_0107_1_1');

    final ongoingReq = OngoingSupportCreateRequest(
      clientId: 'client-1',
      title: 'Support',
      clientSiteId: 'site-1',
      rrule: 'FREQ=WEEKLY',
      dtstart: DateTime.utc(2026, 7, 30, 9),
      timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
      horizonFrom: DateTime.utc(2026, 8, 3),
      horizonTo: DateTime.utc(2026, 8, 17),
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );
    expect(ongoingReq.toJson()['support_item_code'], '01_011_0107_1_1');
  });
}
