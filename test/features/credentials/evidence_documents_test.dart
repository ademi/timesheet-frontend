import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/features/credentials/data/evidence_documents.dart';

void main() {
  test('selects documents by credential id before category', () {
    const firstPoliceCheck = DocumentOut(
      id: 'first-police-check-document',
      ownerType: 'contractor',
      ownerId: 'contractor-id',
      filename: 'first-police-check.pdf',
      contentType: 'application/pdf',
      sizeBytes: 100,
      scanStatus: 'clean',
      category: 'police_check',
      credentialId: 'first-police-check',
    );
    const secondPoliceCheck = DocumentOut(
      id: 'second-police-check-document',
      ownerType: 'contractor',
      ownerId: 'contractor-id',
      filename: 'second-police-check.pdf',
      contentType: 'application/pdf',
      sizeBytes: 100,
      scanStatus: 'clean',
      category: 'police_check',
      credentialId: 'second-police-check',
    );
    const legacyPoliceCheck = DocumentOut(
      id: 'legacy-police-check-document',
      ownerType: 'contractor',
      ownerId: 'contractor-id',
      filename: 'legacy-police-check.pdf',
      contentType: 'application/pdf',
      sizeBytes: 100,
      scanStatus: 'clean',
      category: 'police_check',
    );

    final evidence = documentsForCredential(
      documents: [firstPoliceCheck, secondPoliceCheck, legacyPoliceCheck],
      credentialId: 'second-police-check',
      credentialType: 'police_check',
    );

    expect(evidence.map((document) => document.id), [
      'second-police-check-document',
      'legacy-police-check-document',
    ]);
  });
}
