import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/widgets/credential_status_chip.dart';

void main() {
  test('credentialStatusLabel maps known statuses', () {
    expect(credentialStatusLabel('active'), 'Active');
    expect(credentialStatusLabel('superseded'), 'Superseded');
    expect(credentialStatusLabel('withdrawn'), 'Withdrawn');
    expect(credentialStatusLabel('accepted'), 'Accepted');
    expect(credentialStatusLabel('rejected'), 'Rejected');
    expect(credentialStatusLabel('pending'), 'Pending review');
    expect(credentialStatusLabel('re_review_required'), 'Re-review required');
  });
}
