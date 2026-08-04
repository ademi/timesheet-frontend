import '../datasources/credentials_remote_datasource.dart';
import '../models/credential_models.dart';

class CredentialsRepository {
  CredentialsRepository({required CredentialsRemoteDataSource remote})
      : _remote = remote;

  final CredentialsRemoteDataSource _remote;

  Future<List<CredentialCategory>> listCredentialCategories() async {
    final categories = await _remote.listCredentialCategories();
    cacheCredentialCategoryLabels(categories);
    return categories;
  }

  Future<List<CredentialOut>> listMine() => _remote.listMine();

  Future<CredentialOut> create(CredentialCreateRequest body) =>
      _remote.create(body);

  Future<CredentialOut> patch(String id, CredentialUpdateRequest body) =>
      _remote.patch(id, body);

  Future<CredentialOut> supersede(
    String id,
    CredentialSupersedeRequest body,
  ) =>
      _remote.supersede(id, body);

  Future<List<CredentialOut>> listForTenantContractor(
    String contractorId, {
    required String engagementId,
  }) =>
      _remote.listForTenantContractor(
        contractorId,
        engagementId: engagementId,
      );

  Future<CredentialReviewOut> createReview({
    required String engagementId,
    required CredentialReviewCreateRequest body,
  }) =>
      _remote.createReview(engagementId: engagementId, body: body);
}
