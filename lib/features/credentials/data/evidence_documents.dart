import '../../../app/data/models/document/document_models.dart';

/// The documents API exposes evidence by contractor ownership. Categories let
/// credential screens display the files associated with each credential type.
List<DocumentOut> documentsForCredentialType({
  required Iterable<DocumentOut> documents,
  required String credentialType,
}) {
  return documents
      .where((document) => document.category == credentialType)
      .toList(growable: false);
}
