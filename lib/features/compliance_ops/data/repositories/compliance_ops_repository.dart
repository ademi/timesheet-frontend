import '../datasources/compliance_ops_remote_datasource.dart';
import '../models/compliance_ops_models.dart';

class ComplianceOpsRepository {
  ComplianceOpsRepository({required ComplianceOpsRemoteDataSource remote})
      : _remote = remote;

  final ComplianceOpsRemoteDataSource _remote;

  Future<RightsRequestOut> createRightsRequest(RightsRequestCreate body) =>
      _remote.createRightsRequest(body);

  Future<RightsRequestOut> getRightsRequest(String id) =>
      _remote.getRightsRequest(id);

  Future<List<RightsRequestOut>> listRightsRequests() =>
      _remote.listRightsRequests();

  Future<PrivacyExportResult> privacyExport() => _remote.privacyExport();

  Future<List<AccessHistoryEntry>> listAccessHistory() =>
      _remote.listAccessHistory();

  Future<List<IncidentOut>> listIncidents() => _remote.listIncidents();

  Future<IncidentOut> getIncident(String id) => _remote.getIncident(id);

  Future<IncidentOut> createIncident(IncidentCreate body) =>
      _remote.createIncident(body);

  Future<IncidentOut> patchIncident(String id, {String? status}) =>
      _remote.patchIncident(id, status: status);

  Future<List<NotificationEventOut>> listNotificationEvents({int limit = 50}) =>
      _remote.listNotificationEvents(limit: limit);

  Future<SubscriptionStatusOut> getSubscription() =>
      _remote.getSubscription();

  Future<List<TenantMemberOut>> listTenantMembers() =>
      _remote.listTenantMembers();

  Future<void> withdrawConsent({
    required String credentialType,
    String? notes,
  }) =>
      _remote.withdrawConsent(credentialType: credentialType, notes: notes);
}
