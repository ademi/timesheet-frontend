import '../../../../shared/models/profile_photo_models.dart';
import '../../../../shared/utils/name_sort.dart';
import '../../../visits/data/models/roster_overlay_models.dart';
import '../datasources/engagements_remote_datasource.dart';
import '../models/engagement_models.dart';

class EngagementsRepository {
  EngagementsRepository({required EngagementsRemoteDataSource remote})
    : _remote = remote;

  final EngagementsRemoteDataSource _remote;

  Future<List<EngagementOut>> listTenantEngagements() async =>
      sortedByName(await _remote.listTenantEngagements(), (e) => e.displayName);

  Future<EngagementInviteResponse> invite(EngagementInviteRequest body) =>
      _remote.invite(body);

  Future<EngagementInvitePreviewOut> previewInvite(
    EngagementInvitePreviewRequest body,
  ) => _remote.previewInvite(body);

  Future<List<EngagementOut>> listMyEngagements() async =>
      sortedByName(
        await _remote.listMyEngagements(),
        (e) => e.tenantName ?? e.tenantId,
      );

  Future<EngagementOut> accept({
    required String engagementId,
    required EngagementAcceptRequest body,
  }) => _remote.accept(engagementId: engagementId, body: body);

  Future<EngagementOut> approve(String id) => _remote.approve(id);
  Future<EngagementOut> activate(String id) => _remote.activate(id);
  Future<EngagementOut> approveAndActivate(String id) =>
      _remote.approveAndActivate(id);
  Future<EngagementOut> suspend(String id) => _remote.suspend(id);
  Future<EngagementOut> resume(String id) => _remote.resume(id);
  Future<EngagementOut> end(String id) => _remote.end(id);

  Future<EngagementOut> replaceRequiredDocCategories({
    required String engagementId,
    required List<String> categories,
  }) => _remote.replaceRequiredDocCategories(
        engagementId: engagementId,
        categories: categories,
      );

  Future<void> createSharingAccessRequest({
    required String engagementId,
    bool allowSourceEvidence = true,
  }) => _remote.createSharingAccessRequest(
    engagementId: engagementId,
    allowSourceEvidence: allowSourceEvidence,
  );

  Future<ProfilePhotoOut> getContractorProfilePhoto(String contractorId) =>
      _remote.getContractorProfilePhoto(contractorId);

  Future<List<AvailabilityRuleOut>> listAvailability(String engagementId) =>
      _remote.listAvailability(engagementId);
}
