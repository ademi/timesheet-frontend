import '../../../app/data/models/document/document_models.dart';

/// Returns documents bound to [credentialId] only.
List<DocumentOut> documentsForCredential({
  required Iterable<DocumentOut> documents,
  required String credentialId,
  required String credentialType,
}) {
  return documents
      .where((document) => document.credentialId == credentialId)
      .toList(growable: false);
}
