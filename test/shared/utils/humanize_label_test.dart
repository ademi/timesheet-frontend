import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/utils/humanize_label.dart';

void main() {
  test('humanizeLabel title-cases snake_case words', () {
    expect(
      humanizeLabel('other_health_qualification'),
      'Other Health Qualification',
    );
    expect(humanizeLabel('first_aid'), 'First Aid');
    expect(humanizeLabel('medication_admin'), 'Medication Admin');
    expect(humanizeLabel('cert_iii'), 'Cert III');
  });

  test('humanizeLabel uppercases known acronyms', () {
    expect(humanizeLabel('cpr'), 'CPR');
    expect(humanizeLabel('ndis_worker_screening'), 'NDIS Worker Screening');
  });

  test('humanizeLabel leaves NDIS item codes and UUIDs alone', () {
    expect(humanizeLabel('01_002_0107_1_1'), '01_002_0107_1_1');
    expect(
      humanizeLabel('c2000001-0002-4002-8002-000000000001'),
      'c2000001-0002-4002-8002-000000000001',
    );
  });

  test('humanizeLabel handles empty and already spaced', () {
    expect(humanizeLabel(''), '');
    expect(humanizeLabel('  pending_docs  '), 'Pending Docs');
  });
}
