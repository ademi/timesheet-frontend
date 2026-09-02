import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';

void main() {
  setUp(clearCredentialCategoryLabelCache);

  test('includes uploaded evidence document ids in create payload', () {
    const request = CredentialCreateRequest(
      credentialType: 'wwcc',
      noticeEventId: 'notice-event-id',
      evidenceDocumentIds: ['evidence-document-id'],
    );

    expect(request.toJson()['evidence_document_ids'], ['evidence-document-id']);
  });

  test('credentialTypeLabel uses fallback map for known codes', () {
    expect(credentialTypeLabel('passport_id'), 'Passport');
    expect(credentialTypeLabel('drivers_licence'), 'Driver licence');
    expect(credentialTypeLabel('wwcc'), 'Working with Children Check');
    expect(
      credentialTypeLabel('ndis_worker_screening'),
      'NDIS Worker Screening Check',
    );
  });

  test('credentialTypeLabel prefers cached catalog labels', () {
    cacheCredentialCategoryLabels(const [
      CredentialCategory(code: 'wwcc', label: 'WWCC (catalog)'),
    ]);
    expect(credentialTypeLabel('wwcc'), 'WWCC (catalog)');
    expect(credentialTypeLabel('passport_id'), 'Passport');
  });

  test('CredentialCategory.fromJson falls back when label missing', () {
    final category = CredentialCategory.fromJson({'code': 'cpr'});
    expect(category.code, 'cpr');
    expect(category.label, 'CPR');
  });

  test('CredentialCategory.fromJson parses help_url', () {
    final category = CredentialCategory.fromJson({
      'code': 'wwcc',
      'label': 'Working with Children Check',
      'help_url': 'https://example.com/wwcc',
    });
    expect(category.helpUrl, 'https://example.com/wwcc');
  });

  test('credentialTypeHelpUrl uses cached catalog values', () {
    cacheCredentialCategoryLabels(const [
      CredentialCategory(
        code: 'ndis_induction',
        label: 'NDIS induction',
        helpUrl: 'https://example.com/induction',
      ),
    ]);
    expect(
      credentialTypeHelpUrl('ndis_induction'),
      'https://example.com/induction',
    );
    expect(credentialTypeHelpUrl('wwcc'), isNull);
  });

  test('car insurance label uses fallback map', () {
    expect(credentialTypeLabel('insurance'), 'Car insurance');
  });
}
