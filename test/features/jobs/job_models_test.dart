import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';

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
    expect(rule.contractorName, 'Sam Worker');
  });
}
