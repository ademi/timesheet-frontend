import '../../../app/data/models/document/document_models.dart';

/// Documents explicitly linked to a credential take precedence. Legacy
/// unlinked documents retain category matching until they are re-associated.
List<DocumentOut> documentsForCredential({
  required Iterable<DocumentOut> documents,
  required String credentialId,
  required String credentialType,
}) {
  return documents
      .where(
        (document) =>
            document.credentialId == credentialId ||
            (document.credentialId == null &&
                document.category == credentialType),
      )
      .toList(growable: false);
}
