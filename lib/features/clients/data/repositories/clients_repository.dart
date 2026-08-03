import '../datasources/clients_remote_datasource.dart';
import '../models/client_models.dart';

class ClientsRepository {
  ClientsRepository({required ClientsRemoteDataSource remote}) : _remote = remote;

  final ClientsRemoteDataSource _remote;

  Future<List<ClientOut>> listClients() => _remote.listClients();
  Future<ClientOut> getClient(String id) => _remote.getClient(id);
  Future<ClientOut> createClient(ClientCreateRequest body) =>
      _remote.createClient(body);
  Future<ClientOut> patchClient(String id, ClientUpdateRequest body) =>
      _remote.patchClient(id, body);
  Future<void> deleteClient(String id) => _remote.deleteClient(id);

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
