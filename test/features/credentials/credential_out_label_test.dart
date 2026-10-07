import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';

void main() {
  tearDown(clearCredentialCategoryLabelCache);

  test('CredentialOut.displayLabel prefers row label', () {
    final c = CredentialOut(
      id: '1',
      contractorId: 'c1',
      credentialType: 'other_health_qualification',
      label: 'Other Health Qualification',
      status: 'active',
      provenanceState: 'self_attested',
      evidencePresence: 'present',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    expect(c.displayLabel, 'Other Health Qualification');
  });

  test('CredentialOut.displayLabel falls back to catalog then local map', () {
    cacheCredentialCategoryLabels([
      const CredentialCategory(
        code: 'insurance',
        label: 'Car Insurance',
      ),
    ]);
    final fromCatalog = CredentialOut(
      id: '1',
      contractorId: 'c1',
      credentialType: 'insurance',
      status: 'active',
      provenanceState: 'self_attested',
      evidencePresence: 'present',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    expect(fromCatalog.displayLabel, 'Car Insurance');

    clearCredentialCategoryLabelCache();
    expect(fromCatalog.displayLabel, 'Car Insurance');
  });

  test('fromJson reads optional label', () {
    final c = CredentialOut.fromJson({
      'id': '1',
      'contractor_id': 'c1',
      'credential_type': 'first_aid',
      'label': 'First Aid',
      'status': 'active',
      'provenance_state': 'x',
      'evidence_presence': 'present',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });
    expect(c.label, 'First Aid');
    expect(c.displayLabel, 'First Aid');
  });
}
