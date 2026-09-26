import '../datasources/sil_remote_datasource.dart';
import '../models/sil_models.dart';

class SilRepository {
  SilRepository(this._remote);

  final SilRemoteDataSource _remote;

  Future<List<SilHouseOut>> listHouses() => _remote.listHouses();

  Future<SilHouseOut> createHouse(SilHouseCreateRequest body) =>
      _remote.createHouse(body);

  Future<SilHouseBundleOut> getHouse(String houseId) =>
      _remote.getHouse(houseId);

  Future<SilHouseMemberOut> upsertMember(
    String houseId,
    SilHouseMemberUpsertRequest body,
  ) => _remote.upsertMember(houseId, body);

  Future<SilRocBlockOut> upsertRocBlock(
    String houseId,
    SilRocBlockUpsertRequest body,
  ) => _remote.upsertRocBlock(houseId, body);

  Future<void> linkJobHouse(String jobId, String? silHouseId) =>
      _remote.linkJobHouse(jobId, silHouseId);
}
