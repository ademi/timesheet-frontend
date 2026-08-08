import '../../../../shared/models/profile_photo_models.dart';
import '../datasources/clients_remote_datasource.dart';
import '../models/client_models.dart';
import '../models/client_profile_models.dart';

class ClientsRepository {
  ClientsRepository({required ClientsRemoteDataSource remote}) : _remote = remote;

  final ClientsRemoteDataSource _remote;

  Future<List<ClientTypeOut>> listClientTypes() => _remote.listClientTypes();
  Future<List<ClientTypeRequirement>> listTypeRequirements(
    String clientTypeId,
  ) =>
      _remote.listTypeRequirements(clientTypeId);
  Future<ClientProfileBundle> getClientProfile(String clientId) =>
      _remote.getClientProfile(clientId);
  Future<void> upsertProfileFact(
    String clientId,
    String requirementKey,
    ProfileFactUpsert body,
  ) =>
      _remote.upsertProfileFact(clientId, requirementKey, body);
  Future<void> submitClientForm(
    String clientId,
    String formKey,
    ClientFormSubmitRequest body,
  ) =>
      _remote.submitClientForm(clientId, formKey, body);
  Future<ClientLegalDocumentCurrent> getLegalDocumentCurrent(
    String legalDocKey,
  ) =>
      _remote.getLegalDocumentCurrent(legalDocKey);
  Future<void> acceptClientLegal(
    String clientId,
    String legalKey,
    ClientLegalAcceptRequest body,
  ) =>
      _remote.acceptClientLegal(clientId, legalKey, body);
  Future<Map<String, dynamic>?> getClientReadiness(String clientId) =>
      _remote.getClientReadiness(clientId);

  Future<List<ClientOut>> listClients() => _remote.listClients();
  Future<ClientOut> getClient(String id) => _remote.getClient(id);
  Future<ClientOut> createClient(ClientCreateRequest body) =>
      _remote.createClient(body);
  Future<ClientOut> patchClient(String id, ClientUpdateRequest body) =>
      _remote.patchClient(id, body);
  Future<void> deleteClient(String id) => _remote.deleteClient(id);

  Future<ProfilePhotoOut> getClientProfilePhoto(String clientId) =>
      _remote.getClientProfilePhoto(clientId);
  Future<ProfilePhotoOut> setClientProfilePhoto(
    String clientId,
    String documentId,
  ) =>
      _remote.setClientProfilePhoto(clientId, documentId);
  Future<ProfilePhotoOut> clearClientProfilePhoto(String clientId) =>
      _remote.clearClientProfilePhoto(clientId);

  Future<List<ClientSiteOut>> listSites(String clientId) =>
      _remote.listSites(clientId);
  Future<ClientSiteOut> createSite(
    String clientId,
    ClientSiteWriteRequest body,
  ) =>
      _remote.createSite(clientId, body);
  Future<ClientSiteOut> patchSite(
    String clientId,
    String siteId,
    ClientSiteWriteRequest body,
  ) =>
      _remote.patchSite(clientId, siteId, body);
  Future<void> deleteSite(String clientId, String siteId) =>
      _remote.deleteSite(clientId, siteId);

  Future<List<ClientContactOut>> listContacts(String clientId) =>
      _remote.listContacts(clientId);
  Future<ClientContactOut> createContact(
    String clientId,
    ClientContactWriteRequest body,
  ) =>
      _remote.createContact(clientId, body);
  Future<ClientContactOut> patchContact(
    String clientId,
    String contactId,
    ClientContactWriteRequest body,
  ) =>
      _remote.patchContact(clientId, contactId, body);
  Future<void> deleteContact(String clientId, String contactId) =>
      _remote.deleteContact(clientId, contactId);

  Future<ClientInviteCreateResponse> createInvite(String clientId) =>
      _remote.createInvite(clientId);
  Future<List<ClientInviteOut>> listInvites(String clientId) =>
      _remote.listInvites(clientId);

  Future<GeocodeResponse> geocode(GeocodeRequest body) => _remote.geocode(body);

  Future<ClientInvitePublicOut> getPublicInvite(String token) =>
      _remote.getPublicInvite(token);
  Future<ClientInviteAcknowledgeResponse> acknowledgePublicInvite({
    required String token,
    bool accept = true,
  }) =>
      _remote.acknowledgePublicInvite(token: token, accept: accept);
}
