import '../datasources/compliance_remote_datasource.dart';
import '../models/compliance_models.dart';

class ComplianceRepository {
  ComplianceRepository({required ComplianceRemoteDataSource remote})
      : _remote = remote;

  final ComplianceRemoteDataSource _remote;

  Future<LegalDocumentCurrent> getCurrentLegalDocument(String docKey) =>
      _remote.getCurrentLegalDocument(docKey);

  Future<List<CollectionNotice>> listCollectionNotices({
    String? credentialType,
    String? jurisdiction,
  }) =>
      _remote.listCollectionNotices(
        credentialType: credentialType,
        jurisdiction: jurisdiction,
      );

  Future<LegalEventResult> createLegalEvent(
    LegalEventCreate body, {
    String? idempotencyKey,
  }) =>
      _remote.createLegalEvent(body, idempotencyKey: idempotencyKey);
}
