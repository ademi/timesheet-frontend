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
}
