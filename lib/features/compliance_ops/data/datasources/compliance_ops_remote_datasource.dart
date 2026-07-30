import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/compliance_ops_models.dart';

class ComplianceOpsRemoteDataSource {
  ComplianceOpsRemoteDataSource({required Dio authenticatedDio})
      : _dio = authenticatedDio;

  final Dio _dio;

  Future<RightsRequestOut> createRightsRequest(RightsRequestCreate body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.rightsRequests,
        data: body.toJson(),
      );
      return _require(response.data, RightsRequestOut.fromJson, 'rights request');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<RightsRequestOut> getRightsRequest(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.rightsRequest(id),
      );
      return _require(response.data, RightsRequestOut.fromJson, 'rights request');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<RightsRequestOut>> listRightsRequests({int limit = 100}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiPaths.rightsRequests,
        queryParameters: {'limit': limit},
      );
      return _parseList(response.data, RightsRequestOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<PrivacyExportResult> privacyExport() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.contractorMePrivacyExport,
      );
      final data = response.data ?? <String, dynamic>{};
      return PrivacyExportResult.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<AccessHistoryEntry>> listAccessHistory({
    required String credentialId,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiPaths.accessHistory,
        queryParameters: {
          'credential_id': credentialId,
          'limit': limit,
        },
      );
      return _parseList(response.data, AccessHistoryEntry.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<IncidentOut>> listIncidents({int limit = 100}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiPaths.incidents,
        queryParameters: {'limit': limit},
      );
      return _parseList(response.data, IncidentOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<IncidentOut> getIncident(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.incident(id),
      );
      return _require(response.data, IncidentOut.fromJson, 'incident');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<IncidentOut> createIncident(IncidentCreate body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.incidents,
        data: body.toJson(),
      );
      return _require(response.data, IncidentOut.fromJson, 'create incident');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<IncidentOut> patchIncident(String id, {String? status}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.incident(id),
        data: {
          if (status != null) 'status': status,
        },
      );
      return _require(response.data, IncidentOut.fromJson, 'patch incident');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<NotificationEventOut>> listNotificationEvents({
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiPaths.notificationEvents,
        queryParameters: {'limit': limit},
      );
      return _parseList(response.data, NotificationEventOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<SubscriptionStatusOut> getSubscription() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.subscription,
      );
      final data = response.data ?? <String, dynamic>{};
      return SubscriptionStatusOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<TenantMemberOut>> listTenantMembers({int limit = 100}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiPaths.tenantMembers,
        queryParameters: {'limit': limit},
      );
      return _parseList(response.data, TenantMemberOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> withdrawConsent({
    required String credentialType,
    String? notes,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiPaths.legalEvents,
        data: {
          'event_type': 'withdrawn',
          'credential_type': credentialType,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  List<T> _parseList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }
    if (data is Map) {
      final items = data['items'] ?? data['events'] ?? data['results'] ?? data['data'];
      if (items is List) return _parseList(items, fromJson);
    }
    return const [];
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
