import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../shared/models/profile_photo_models.dart';
import '../../../visits/data/models/roster_overlay_models.dart';
import '../models/engagement_models.dart';

class EngagementsRemoteDataSource {
  EngagementsRemoteDataSource({required Dio authenticatedDio})
    : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<EngagementOut>> listTenantEngagements() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.tenantEngagements,
      );
      return _mapList(response.data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<EngagementInviteResponse> invite(EngagementInviteRequest body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.tenantEngagements,
        data: body.toJson(),
      );
      return _requireInviteResponse(response.data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<EngagementInvitePreviewOut> previewInvite(
    EngagementInvitePreviewRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.tenantEngagementInvitePreview,
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_preview',
          message: 'Empty invite preview response',
          presentation: AppFailurePresentation.inline,
        );
      }
      return EngagementInvitePreviewOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<EngagementOut>> listMyEngagements() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.contractorMeEngagements,
      );
      return _mapList(response.data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<EngagementOut> accept({
    required String engagementId,
    required EngagementAcceptRequest body,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.engagementAccept(engagementId),
        data: body.toJson(),
      );
      return _requireOut(response.data, 'accept');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<EngagementOut> approve(String engagementId) =>
      _lifecycle(ApiPaths.engagementApprove(engagementId), 'approve');

  Future<EngagementOut> activate(String engagementId) =>
      _lifecycle(ApiPaths.engagementActivate(engagementId), 'activate');

  Future<EngagementOut> approveAndActivate(String engagementId) => _lifecycle(
    ApiPaths.engagementApproveAndActivate(engagementId),
    'approve-and-activate',
  );

  Future<EngagementOut> suspend(String engagementId) =>
      _lifecycle(ApiPaths.engagementSuspend(engagementId), 'suspend');

  Future<EngagementOut> resume(String engagementId) =>
      _lifecycle(ApiPaths.engagementResume(engagementId), 'resume');

  Future<EngagementOut> end(String engagementId) =>
      _lifecycle(ApiPaths.engagementEnd(engagementId), 'end');

  Future<EngagementOut> replaceRequiredDocCategories({
    required String engagementId,
    required List<String> categories,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiPaths.engagementRequiredDocCategories(engagementId),
        data: {'categories': categories},
      );
      return _requireOut(response.data, 'required-doc-categories');
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  /// Staff: request contractor credential share for an engagement.
  Future<void> createSharingAccessRequest({
    required String engagementId,
    bool allowSourceEvidence = true,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiPaths.engagementSharingAccessRequests(engagementId),
        data: {'allow_source_evidence': allowSourceEvidence},
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ProfilePhotoOut> getContractorProfilePhoto(String contractorId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.tenantContractorProfilePhoto(contractorId),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty contractor profile photo response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return ProfilePhotoOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<AvailabilityRuleOut>> listAvailability(
    String engagementId,
  ) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.engagementAvailability(engagementId),
      );
      return _mapAvailabilityList(response.data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<EngagementOut> _lifecycle(String path, String action) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path);
      return _requireOut(response.data, action);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  List<EngagementOut> _mapList(List<dynamic>? raw) {
    final list = raw ?? const [];
    return list
        .whereType<Map>()
        .map((e) => EngagementOut.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  List<AvailabilityRuleOut> _mapAvailabilityList(List<dynamic>? data) {
    if (data == null) return const [];
    return data
        .whereType<Map>()
        .map((e) => AvailabilityRuleOut.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  EngagementOut _requireOut(Map<String, dynamic>? data, String action) {
    if (data == null) {
      throw AppFailure(
        code: 'unknown',
        message: 'Empty $action response',
        presentation: AppFailurePresentation.toast,
      );
    }
    return EngagementOut.fromJson(data);
  }

  EngagementInviteResponse _requireInviteResponse(Map<String, dynamic>? data) {
    if (data == null) {
      throw AppFailure(
        code: 'unknown',
        message: 'Empty invite response',
        presentation: AppFailurePresentation.toast,
      );
    }
    return EngagementInviteResponse.fromJson(data);
  }
}
