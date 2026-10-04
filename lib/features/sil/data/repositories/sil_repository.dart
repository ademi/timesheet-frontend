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

  Future<SilHouseOut> patchHouse(String houseId, SilHousePatchRequest body) =>
      _remote.patchHouse(houseId, body);

  Future<SilVacancyOverlayOut> getOverlay(String houseId) =>
      _remote.getOverlay(houseId);

  Future<SilFillVacancyOut> fillVacancy(
    String houseId,
    SilFillVacancyRequest body,
  ) => _remote.fillVacancy(houseId, body);

  Future<List<SilCompatRuleOut>> listCompatRules(String houseId) =>
      _remote.listCompatRules(houseId);

  Future<SilCompatRuleOut> createCompatRule(
    String houseId,
    SilCompatRuleCreateRequest body,
  ) => _remote.createCompatRule(houseId, body);

  Future<void> deleteCompatRule(String houseId, String ruleId) =>
      _remote.deleteCompatRule(houseId, ruleId);
}
