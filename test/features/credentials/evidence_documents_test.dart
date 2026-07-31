import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/features/credentials/data/evidence_documents.dart';

void main() {
  test('keeps real document ids while selecting credential evidence', () {
    const policeCheck = DocumentOut(
      id: 'police-check-document',
      ownerType: 'contractor',
      ownerId: 'contractor-id',
      filename: 'police-check.pdf',
      contentType: 'application/pdf',
      sizeBytes: 100,
      scanStatus: 'clean',
      category: 'police_check',
    );
    const firstAid = DocumentOut(
      id: 'first-aid-document',
      ownerType: 'contractor',
      ownerId: 'contractor-id',
      filename: 'first-aid.pdf',
      contentType: 'application/pdf',
      sizeBytes: 100,
      scanStatus: 'clean',
      category: 'first_aid',
    );

    final evidence = documentsForCredentialType(
      documents: [policeCheck, firstAid],
      credentialType: 'police_check',
    );

    expect(evidence.map((document) => document.id), ['police-check-document']);
  });
}
