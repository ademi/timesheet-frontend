import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';

void main() {
  test('includes uploaded evidence document ids in create payload', () {
    const request = CredentialCreateRequest(
      credentialType: 'wwcc',
      noticeEventId: 'notice-event-id',
      evidenceDocumentIds: ['evidence-document-id'],
    );

    expect(request.toJson()['evidence_document_ids'], ['evidence-document-id']);
  });
}
