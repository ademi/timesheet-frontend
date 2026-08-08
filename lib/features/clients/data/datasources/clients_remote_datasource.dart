import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../shared/models/profile_photo_models.dart';
import '../models/client_models.dart';
import '../models/client_profile_models.dart';

class ClientsRemoteDataSource {
  ClientsRemoteDataSource({
    required Dio authenticatedDio,
    required Dio plainDio,
  })  : _dio = authenticatedDio,
        _plain = plainDio;

  final Dio _dio;
  final Dio _plain;

  Future<List<ClientTypeOut>> listClientTypes() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiPaths.clientTypes);
      return _mapList(response.data, ClientTypeOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<ClientTypeRequirement>> listTypeRequirements(
    String clientTypeId,
  ) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.clientTypeRequirements(clientTypeId),
      );
      final items = _mapList(response.data, ClientTypeRequirement.fromJson);
      final sorted = [...items]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return sorted;
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientProfileBundle> getClientProfile(String clientId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.clientProfile(clientId),
      );
      return _require(response.data, ClientProfileBundle.fromJson, 'profile');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> upsertProfileFact(
    String clientId,
    String requirementKey,
    ProfileFactUpsert body,
  ) async {
    try {
      await _dio.put<void>(
        ApiPaths.clientProfileFact(clientId, requirementKey),
        data: body.toJson(),
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> submitClientForm(
    String clientId,
    String formKey,
    ClientFormSubmitRequest body,
  ) async {
    try {
      await _dio.post<void>(
        ApiPaths.clientForm(clientId, formKey),
        data: body.toJson(),
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientLegalDocumentCurrent> getLegalDocumentCurrent(
    String legalDocKey,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.clientLegalDocumentCurrent(legalDocKey),
      );
      return _require(
        response.data,
        ClientLegalDocumentCurrent.fromJson,
        'legal document',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> acceptClientLegal(
    String clientId,
    String legalKey,
    ClientLegalAcceptRequest body,
  ) async {
    try {
      await _dio.post<void>(
        ApiPaths.clientLegal(clientId, legalKey),
        data: body.toJson(),
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<Map<String, dynamic>?> getClientReadiness(String clientId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.clientReadiness(clientId),
      );
      return response.data;
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<ClientOut>> listClients() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiPaths.clients);
      return _mapList(response.data, ClientOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientOut> getClient(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiPaths.client(id));
      return _require(response.data, ClientOut.fromJson, 'client');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientOut> createClient(ClientCreateRequest body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.clients,
        data: body.toJson(),
      );
      return _require(response.data, ClientOut.fromJson, 'create client');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientOut> patchClient(String id, ClientUpdateRequest body) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.client(id),
        data: body.toJson(),
      );
      return _require(response.data, ClientOut.fromJson, 'patch client');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ProfilePhotoOut> getClientProfilePhoto(String clientId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.clientProfilePhoto(clientId),
      );
      return _require(
        response.data,
        ProfilePhotoOut.fromJson,
        'client profile photo',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ProfilePhotoOut> setClientProfilePhoto(
    String clientId,
    String documentId,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiPaths.clientProfilePhoto(clientId),
        data: ProfilePhotoSetRequest(documentId: documentId).toJson(),
      );
      return _require(
        response.data,
        ProfilePhotoOut.fromJson,
        'set client profile photo',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ProfilePhotoOut> clearClientProfilePhoto(String clientId) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        ApiPaths.clientProfilePhoto(clientId),
      );
      return _require(
        response.data,
        ProfilePhotoOut.fromJson,
        'clear client profile photo',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> deleteClient(String id) async {
    try {
      await _dio.delete<void>(ApiPaths.client(id));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<ClientSiteOut>> listSites(String clientId) async {
    try {
      final response =
          await _dio.get<List<dynamic>>(ApiPaths.clientSites(clientId));
      return _mapList(response.data, ClientSiteOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientSiteOut> createSite(
    String clientId,
    ClientSiteWriteRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.clientSites(clientId),
        data: body.toJson(),
      );
      return _require(response.data, ClientSiteOut.fromJson, 'create site');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientSiteOut> patchSite(
    String clientId,
    String siteId,
    ClientSiteWriteRequest body,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.clientSite(clientId, siteId),
        data: body.toJson(),
      );
      return _require(response.data, ClientSiteOut.fromJson, 'patch site');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> deleteSite(String clientId, String siteId) async {
    try {
      await _dio.delete<void>(ApiPaths.clientSite(clientId, siteId));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<ClientContactOut>> listContacts(String clientId) async {
    try {
      final response =
          await _dio.get<List<dynamic>>(ApiPaths.clientContacts(clientId));
      return _mapList(response.data, ClientContactOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientContactOut> createContact(
    String clientId,
    ClientContactWriteRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.clientContacts(clientId),
        data: body.toJson(),
      );
      return _require(response.data, ClientContactOut.fromJson, 'create contact');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientContactOut> patchContact(
    String clientId,
    String contactId,
    ClientContactWriteRequest body,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.clientContact(clientId, contactId),
        data: body.toJson(),
      );
      return _require(response.data, ClientContactOut.fromJson, 'patch contact');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> deleteContact(String clientId, String contactId) async {
    try {
      await _dio.delete<void>(ApiPaths.clientContact(clientId, contactId));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientInviteCreateResponse> createInvite(String clientId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.clientInvites(clientId),
      );
      return _require(
        response.data,
        ClientInviteCreateResponse.fromJson,
        'create invite',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<ClientInviteOut>> listInvites(String clientId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.clientInvites(clientId),
      );
      return _mapList(response.data, ClientInviteOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<GeocodeResponse> geocode(GeocodeRequest body) async {
    try {
      final response = await _plain.post<Map<String, dynamic>>(
        ApiPaths.publicGeocode,
        data: body.toJson(),
      );
      return _require(response.data, GeocodeResponse.fromJson, 'geocode');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientInvitePublicOut> getPublicInvite(String token) async {
    try {
      final response = await _plain.get<Map<String, dynamic>>(
        ApiPaths.publicClientInvite(token),
      );
      return _require(
        response.data,
        ClientInvitePublicOut.fromJson,
        'public invite',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ClientInviteAcknowledgeResponse> acknowledgePublicInvite({
    required String token,
    bool accept = true,
  }) async {
    try {
      final response = await _plain.post<Map<String, dynamic>>(
        ApiPaths.publicClientInviteAcknowledge(token),
        data: {'accept': accept},
      );
      return _require(
        response.data,
        ClientInviteAcknowledgeResponse.fromJson,
        'acknowledge invite',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  List<T> _mapList<T>(
    List<dynamic>? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = raw ?? const [];
    return list
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  T _require<T>(
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>) fromJson,
    String label,
  ) {
    if (data == null) {
      throw AppFailure(
        code: 'unknown',
        message: 'Empty $label response',
        presentation: AppFailurePresentation.toast,
      );
    }
    return fromJson(data);
  }
}
