import '../datasources/ndis_catalogue_remote_datasource.dart';
import '../models/billing_models.dart';

class NdisCatalogueRepository {
  NdisCatalogueRepository({required NdisCatalogueRemoteDataSource remote})
      : _remote = remote;

  final NdisCatalogueRemoteDataSource _remote;

  Future<NdisCatalogueSearchResponse> searchItems({
    required String q,
    int limit = 20,
  }) =>
      _remote.searchItems(q: q, limit: limit);
}
