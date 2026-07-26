import '../datasources/engagements_remote_datasource.dart';
import '../models/engagement_models.dart';

class EngagementsRepository {
  EngagementsRepository({required EngagementsRemoteDataSource remote})
      : _remote = remote;

  final EngagementsRemoteDataSource _remote;

  Future<List<EngagementOut>> listTenantEngagements() =>
      _remote.listTenantEngagements();

  Future<EngagementOut> invite(EngagementInviteRequest body) =>
      _remote.invite(body);

  Future<List<EngagementOut>> listMyEngagements() =>
      _remote.listMyEngagements();

  Future<EngagementOut> accept({
    required String engagementId,
    required EngagementAcceptRequest body,
  }) =>
      _remote.accept(engagementId: engagementId, body: body);

  Future<EngagementOut> approve(String id) => _remote.approve(id);
  Future<EngagementOut> activate(String id) => _remote.activate(id);
  Future<EngagementOut> approveAndActivate(String id) =>
      _remote.approveAndActivate(id);
  Future<EngagementOut> suspend(String id) => _remote.suspend(id);
  Future<EngagementOut> resume(String id) => _remote.resume(id);
  Future<EngagementOut> end(String id) => _remote.end(id);
}
