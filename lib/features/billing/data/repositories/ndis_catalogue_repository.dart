import '../datasources/ndis_catalogue_remote_datasource.dart';
import '../models/billing_models.dart';

class NdisCatalogueRepository {
  NdisCatalogueRepository({required NdisCatalogueRemoteDataSource remote})
    : _remote = remote;

  final NdisCatalogueRemoteDataSource _remote;

  List<NdisCatalogueItemOut>? _cachedItems;
  Future<List<NdisCatalogueItemOut>>? _inFlight;

  /// Session-cached full catalogue. Hits the network once until [clearCache].
  ///
  /// Picker path must use this plus [NdisCatalogueLocalFilter] — not
  /// per-keystroke [searchItems] and not a `/facets` HTTP call.
  Future<List<NdisCatalogueItemOut>> fetchAllActiveItems({int limit = 1000}) {
    final cached = _cachedItems;
    if (cached != null) {
      return Future<List<NdisCatalogueItemOut>>.value(cached);
    }

    return _inFlight ??= _remote
        .fetchAllActiveItems(limit: limit)
        .then((items) {
          _cachedItems = items;
          return items;
        })
        .whenComplete(() {
          _inFlight = null;
        });
  }

  void clearCache() {
    _cachedItems = null;
    _inFlight = null;
  }

  Future<NdisCatalogueSearchResponse> searchItems({
    required String q,
    int limit = 20,
  }) => _remote.searchItems(q: q, limit: limit);
}
