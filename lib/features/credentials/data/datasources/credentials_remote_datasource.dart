import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/credential_models.dart';

class CredentialsRemoteDataSource {
  CredentialsRemoteDataSource({required Dio authenticatedDio})
      : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<CredentialCategory>> listCredentialCategories() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.credentialCategories,
      );
      final list = response.data ?? const [];
      return list
          .whereType<Map>()
          .map(
            (e) => CredentialCategory.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<CredentialOut>> listMine() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.contractorMeCredentials,
      );
      return _mapList(response.data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<CredentialOut> create(CredentialCreateRequest body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.contractorMeCredentials,
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty credential create response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return CredentialOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<CredentialOut> patch(
    String id,
    CredentialUpdateRequest body,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.contractorMeCredential(id),
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty credential patch response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return CredentialOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<CredentialOut> supersede(
    String id,
    CredentialSupersedeRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.contractorMeCredentialSupersede(id),
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty supersede response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return CredentialOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  /// Staff metadata list (API-003). Requires [engagementId]; no sharing grant.
  Future<List<CredentialOut>> listForTenantContractor(
    String contractorId, {
    required String engagementId,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.tenantContractorCredentials(contractorId),
        queryParameters: {'engagement_id': engagementId},
      );
      return _mapList(response.data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<CredentialReviewOut> createReview({
    required String engagementId,
    required CredentialReviewCreateRequest body,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.engagementCredentialReviews(engagementId),
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty review response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return CredentialReviewOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  List<CredentialOut> _mapList(List<dynamic>? raw) {
    final list = raw ?? const [];
    return list
        .whereType<Map>()
        .map((e) => CredentialOut.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
