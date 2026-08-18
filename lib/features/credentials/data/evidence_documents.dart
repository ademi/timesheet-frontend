import '../../../app/data/models/document/document_models.dart';

/// Returns documents bound to [credentialId], or same-category files that
/// were never bound to a credential (legacy uploads).
List<DocumentOut> documentsForCredential({
  required Iterable<DocumentOut> documents,
  required String credentialId,
  required String credentialType,
}) {
  final bound = documents
      .where((document) => document.credentialId == credentialId)
      .toList(growable: false);
  if (bound.isNotEmpty) return bound;

  return documents
      .where(
        (document) =>
            (document.credentialId == null ||
                document.credentialId!.trim().isEmpty) &&
            document.category == credentialType,
      )
      .toList(growable: false);
}
