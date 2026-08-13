import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/utils/job_copy.dart';

void main() {
  test('kindLabel maps schema to coordinator words', () {
    expect(kindLabel('standing'), 'Ongoing support');
    expect(kindLabel('ad_hoc'), 'One-off');
    expect(kindLabel('other'), 'other');
  });

  test('statusLabel maps open/closed/cancelled', () {
    expect(jobStatusLabel('open'), 'Open');
    expect(jobStatusLabel('closed'), 'Ended');
    expect(jobStatusLabel('cancelled'), 'Cancelled');
  });

  test('locationModeLabel never says XOR', () {
    expect(locationModeLabel('site'), "Client's home");
    expect(locationModeLabel('branch'), 'Branch');
    expect(locationModeLabel('site').toLowerCase(), isNot(contains('xor')));
  });

  test('defaultOngoingTitle uses client name', () {
    expect(defaultOngoingTitle('Sam Lee'), 'Sam Lee support');
  });

  test('jobListSubtitle never contains xor or standing', () {
    final s = jobListSubtitle(
      kind: 'standing',
      status: 'open',
      hasSite: true,
      hasBranch: false,
    );
    expect(s.toLowerCase(), isNot(contains('xor')));
    expect(s.toLowerCase(), isNot(contains('standing')));
    expect(s, contains('Ongoing support'));
  });
}
